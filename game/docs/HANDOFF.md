# Handoff — Sovereign Ballgame

Written 2026-09-22, at the point the prototype left the design chat and went to
Claude Code. Read `CLAUDE.md` first for the rules of engagement; this document
is the state of play.

---

## 1. Status, honestly

Everything through the **Challenge** section of `docs/ROADMAP.md` is written.
`gdparse` and `gdlint` pass on all nine scripts.

**Nothing has ever been run.** The prototype was authored in an environment with
no Godot binary, so the editor has never opened the project, no `.godot/` import
folder exists, and no ball has ever bounced. Treat the first F5 as the real
test, not a formality. Section 7 lists where it is most likely to break.

---

## 2. The round loop

This is the spine. Everything else hangs off it.

```
AIMING      arrow keys or A/D rotate the aim line, clamped to +/- max_aim_degrees
            SPACE, or mouse press-drag-release, starts the round
   |
FIRING      Game._tick_firing spawns one ball every ball_fire_interval until
            shots_for_round(ball_count) have left the shooter.
            Each ball reflects off walls, ceiling and blocks at constant speed.
            A block contact costs the block ball_damage and adds to the counters.
            A ball crossing floor_y (or hitting ball_max_lifetime) is finished.
   |
RESOLVING   when the last ball is down:
              1. shooter slides to where the FIRST ball landed
              2. banked +1 ball pickups are added to ball_count
              3. GridManager.spawn_row(round_number + 1) into row 0, which is
                 clear at this point
              4. GridManager.advance() shifts every occupant (including that
                 fresh row) down one row -- row 0 is clear again once this
                 settles
              5. a Block landing in death_row() -> GAME_OVER, round_number
                 NOT incremented (it still names the round that was lost)
              6. otherwise round_number += 1
   |
AIMING      ...
```

Spawn happens BEFORE the shift, not after -- row 0 is meant to read as clear
at every AIMING, the same as it does before round 1. `Game._ready` primes this
by calling `spawn_row` then `advance()` once before the first aim.

`Game.state` is the enum driving this. `_on_ball_finished` is the only thing
that can end a round, and it does so on `_to_fire <= 0 and _live_balls <= 0`.

---

## 3. File map

| File | Holds | Worth knowing |
| --- | --- | --- |
| `scripts/cfg.gd` | `Cfg` autoload — thin index over `scripts/config/*.gd` | Flat re-exports (`Cfg.GRID_WIDTH`) plus namespaced access (`Cfg.Board.GRID_WIDTH`). No runtime-override layer yet — see its header comment. |
| `scripts/config/*.gd` | The numbers, one file per domain (`board`, `spawning`, `ball`, `wall_corners`, `shooter`, `loss`) | Where a value's rationale comment actually lives. `GameRules` preloads these directly rather than reading through `Cfg` — see below. |
| `scripts/game_rules.gd` | Every tunable (defaulted from `scripts/config/*.gd`) + 5 virtual hooks | The mod seam. See §5. |
| `scripts/game.gd` | `Game` — round state machine, playfield construction, scoring, input | `_ready` computes cell size and builds walls; `_draw` paints background, walls, floor line |
| `scripts/grid_manager.gd` | `GridManager` — the block lattice | `cells[row][col]` -> `Block`, `BallPickup` or `null` |
| `scripts/ball.gd` | `Ball` — constant-speed reflector | Manual substep loop, corner jitter, anti-horizontal-stall |
| `scripts/block.gd` | `Block` — numbered brick | `hit(damage) -> int` returns damage absorbed |
| `scripts/ball_pickup.gd` | `BallPickup` — +1 ball | Banked during the round, applied at `_end_round` |
| `scripts/shooter.gd` | `Shooter` — the aim line | 0 deg is straight up, positive is to the right |
| `scripts/hud.gd` | `HUD` — four counters + game over | Labels live in `main.tscn` under `HUD/Root` |
| `scripts/palette.gd` | Shared colours, ROYGBIV health ramp | `Palette.health_color(value, max_value = 100)` |
| `scripts/debug_state.gd` | `Debug` autoload — the debug-mode flag | Session-only; survives a scene reload on purpose. See §9. |
| `scripts/settings_state.gd` | `Settings` autoload — persisted user prefs | UI scale, screen shake strength, SFX/music volume, background-grid toggle. Saved to `user://settings.cfg` on every change. |
| `scripts/skins.gd` | `Skins` autoload — ball/background/block test swatches | Session-only (like `Debug`, not `Settings`). `Palette.health_color()` reads `Skins.block().ramp`. See §10. |
| `scripts/vfx/block_chunk.gd`, `block_fragment.gd` | Hit chunks / destroy fragments | `.new()` + `setup()`, no scene. See §10. |
| `scripts/falling_ball.gd` | `FallingBall` — the +1 ball pickup's cosmetic drop | Reports `landed`; `Game` only increments `pending_balls` on that signal. See §10. |
| `scripts/ui/pause_menu.gd` | `PauseMenu` — 3 pages: root (Resume/Settings/Debug Menu/Main menu), Settings, Debug Menu | Built in code, not `.tscn`; `process_mode = ALWAYS` so it works while paused. See §9. |
| `scripts/ui/debug_overlay.gd` | `DebugOverlay` — row-clear buttons, hold-to-clear-all, on-screen D-pad, expected-count readouts | Visible only while `Debug.enabled`. See §9. |

Scenes are deliberately thin. `main.tscn` is `Main` (Game) with five children:
`Walls`, `Grid`, `Balls`, `Shooter`, `HUD`. `ball/block/pickup.tscn` each carry a
placeholder shape that the owning script replaces in `setup()` / `launch()`.

### Key signatures

```gdscript
# GridManager
func configure(r: GameRules, cell: float, org: Vector2) -> void
func spawn_row(round_number: int) -> void
func advance() -> bool          # true = a Block reached the death row
func shift_up() -> void         # debug only
func cell_center(col: int, row: int) -> Vector2
func block_count() -> int
signal pickup_collected(pickup: BallPickup)
signal block_destroyed(block: Block)

# Ball
func launch(r: GameRules, from: Vector2, dir: Vector2) -> void
signal finished(ball: Ball)                      # crossed the floor or timed out
signal block_damaged(block: Block, damage: int)

# Block
func setup(start_value: int, cell_size: float, col: int, row: int) -> void
func hit(damage: int = 1) -> int                 # returns damage absorbed
signal destroyed(block: Block)
```

Call `setup()` / `launch()` **after** `add_child()` — they touch `@onready`
nodes.

---

## 4. Data model

### The grid

`cells` is `grid_height` rows of `grid_width` entries, row 0 at the top.
Default shape (matching the reference game) is 7 wide, 9 tall.

- **Row 0 is always clear.** `spawn_row` writes the new row there, but
  `Game._end_round` calls it BEFORE `advance()`, so the fresh row is
  immediately carried down to row 1 by the same shift. Row 0 reads as empty at
  every AIMING, including before round 1 (`Game._ready` does the same
  spawn-then-advance once).
- **`rules.death_row()`** (default `grid_height - 1`, the bottom row) ends the
  run. It is drawn with a red tint and a red line so it reads in play.
- The shooter sits *below* the grid, near `floor_y`, not in a grid cell.
- A block therefore survives 7 shifts on the default 9-row board (landing in
  row 1 after its spawning round, then rows 2 through 8) before it kills you.

`advance()` walks bottom-up moving `cells[row-1]` into `cells[row]`, tweens each
node to its new `cell_center`, frees pickups that reach the death row, and
returns `true` if a `Block` ends up there.

Cell size is computed in `Game._ready`: square, sized by width, clamped so a
taller grid still leaves the shooter room. The grid is centred horizontally.

### Row spawning — the important bit

A row is handed **units**, and one unit is worth the **round number**:

```
units      = round(units_per_column * grid_width)     # 7 by default
unit_value = round_number
occupied   = grid_width - open_slots()                # open_slots is 1..3
cap        = max(max_units_per_cell, ceil(units / occupied))   # 4 by default
```

Each occupied column starts at one unit; the remaining units are scattered one
at a time into columns still under `cap`. A block's value is
`its_units * unit_value`.

So **every block in a row is a multiple of the round number**. Round 3 on a
width-7 board spends 7 units of 3 = 21 points, and the row comes out as some
arrangement of 3s, 6s, 9s and 12s across 4–6 columns. Verified across rounds
1–25.

A `+1 ball` pickup drops into a random empty column of row 0 with probability
`pickup_chance` (1.0 by default).

### Collision layers

| Layer | Bit | Who | Mask |
| --- | --- | --- | --- |
| 1 | `walls` | the generated wall body, group `"wall"` | — |
| 2 | `blocks` | `Block` (StaticBody2D) | — |
| 3 | `balls` | `Ball` (CharacterBody2D) | 1 + 2 |
| 4 | `pickups` | `BallPickup` (Area2D, `monitorable = false`) | 3 |

The ball never collides with pickups; the pickup's Area2D detects the ball.

### Input actions

Defined in `project.godot`, not read raw: `aim_left` (A only), `aim_right`
(D only), `fire` (Space), `restart` (R), `pause` (Esc), `debug_left`/
`debug_right`/`debug_up`/`debug_down` (the raw arrows -- debug-only, see §9),
`debug_shift_hold` (Shift). Mouse press-drag-release also aims and fires, via
`Game._unhandled_input` — the HUD root Control is `mouse_filter = 2` so clicks
reach it.

Arrows used to double as `aim_left`/`aim_right` alongside A/D; they were split
out when the debug menu needed the raw arrows for something else entirely
(§9), so aiming is A/D-only now.

---

## 5. The mod layer — where it is going

**Cfg split (added after this doc's original date).** Every `GameRules`
`@export` default now comes from a domain file in `scripts/config/*.gd`
(`board`, `spawning`, `ball`, `wall_corners`, `shooter`, `loss`), indexed by
the `Cfg` autoload (`scripts/cfg.gd`) — same convention as the Sovereign Axe
Battleships project. `GameRules` preloads the domain files directly rather
than reading through `Cfg`, because a `Resource`'s `@export` defaults must
resolve even when the editor instantiates one outside of a running game,
before any autoload exists. `GameRules` stays the mod seam — it still holds
the virtual hooks below and is still what gameplay scripts read — `Cfg` is
just where the raw numbers and their rationale live now, and where any script
that is not a gameplay script can read a constant without going through a
`GameRules` instance. There is no runtime-override layer (`tuned()` /
`set_tuned()`) yet, deliberately: there is no debug menu to write one.

`GameRules` currently exposes five hooks, and they are the proof of concept, not
the finished design:

```gdscript
func death_row() -> int
func row_units(_round_number: int) -> int
func unit_value(round_number: int) -> int
func open_slots() -> int
func shots_for_round(ball_count: int) -> int
```

`docs/ROADMAP.md` has the table mapping each of Theo's mod categories to the
function it will hook. The shape that seems right, **as a proposal to argue
with, not a decision**:

- `GameMod` — a `Resource` with `category: StringName`, a display name, an icon,
  and `apply(rules: GameRules) -> void`. Value-only mods (Dense, Boss, Modified
  grid, Lives) need nothing more than `apply`.
- `ModStack` — a `Resource` holding an `Array[GameMod]`, one per category at
  most, that produces a configured `GameRules` for a run. This is what the mod
  menu edits and what persistence stores.
- Behavioural mods need more than values. Two extra seams, added when the first
  mod in each family lands:
  - `BallBehaviour` — a resource on each ball with `on_spawn`, `on_wall_hit`,
    `on_block_hit`, `on_finish`. Covers Ghost, Missiles, Poison, Snowball,
    Buildup, Zig Zag, Gravity.
  - A spawn-shape hook on `GridManager` taking over the distribution step of
    `spawn_row`. Covers Checkers, Tree, Pawn wall, Virus, the march modes.

Do not build all of this up front. Pick one mod per family, let the seam fall
out of the second one, and keep `GameRules` as the only thing gameplay reads.

---

## 6. Deliberate departures from the original design notes

Both are commented in the code. Do not silently revert them; if you disagree,
raise it with Theo.

1. **Fire interval.** The notes say one ball per second. At round 40 that is a
   forty-second wait before anything happens. Default is `0.09s`, in the
   neighbourhood of the original game. It is `GameRules.ball_fire_interval`.
2. **Ball return.** The notes describe a fixed shooter. The real game moves the
   shooter to where the first ball lands, and the whole rhythm of a round
   depends on it. Implemented and on by default, behind
   `GameRules.balls_return_to_lander`.

A third, now resolved: the notes' `(round + 1) x width` budget with a
`2 x round` per-block cap is unsatisfiable at round 1 (14 points into at most 6
cells capped at 2). The unit model in §4 replaced it and matches Theo's stated
intent exactly.

---

## 7. Where it will break first

In rough order of likelihood:

1. **Balls wedging between adjacent blocks.** Blocks are inset 6% of cell size,
   leaving roughly an 8 px seam against a 34 px ball. It should be impossible to
   enter, but a fast ball arriving at a shallow angle into an inside corner is
   the classic failure. `ball_max_lifetime` (18s) is the backstop, which turns a
   wedge into a lost ball rather than a hung round — acceptable, but if it fires
   often the collision response needs work, not a longer timeout.
2. **Flat horizontal loops.** `_enforce_vertical` forces `|direction.y| >= 0.18`
   after every bounce, and corner jitter scatters wall hits near a corner. If
   balls still lock into a groove, raise `ball_min_vertical` before touching
   anything else.
3. **`.tscn` property names.** The scenes were hand-written, never opened in the
   editor. If a Label's alignment or a node's collision layer comes out wrong,
   that is why — fix it in the editor and save, rather than hand-editing.
4. **`config_version` / `config/features`.** Written for 4.7. If the editor
   offers to convert the project, let it, and commit what it changes as its own
   commit.
5. **HUD anchoring on non-1080x1920 ratios.** Stretch is `canvas_items` /
   `expand`, so a wider phone reveals space at the sides. The labels use fixed
   offsets from the top-left, not anchors. Fine on the S10, wrong on a tablet.

---

## 8. Next tasks, in order

**1. Open it and make it run.** Fix whatever the first F5 turns up. Play ten
rounds. Report what feels wrong about ball speed, fire cadence and difficulty
curve before changing any of them — Theo tunes, you report.

*Acceptance:* a run reaches round 10 and ends with the game-over overlay, no
errors in the output panel, no ball lost to `ball_max_lifetime`.

**2. Finish the Drag step.** Press-drag-release exists. Missing: click the
shooter to focus then click elsewhere to fire, and a dynamic line while
dragging that shows the predicted first bounce or two (raycast against the wall
and block layers, draw the reflected segment).

*Acceptance:* playable with a mouse only, and the predicted line matches where
the first ball actually goes.

**3. Juice.** Hit flash on blocks, a short screen shake on destruction, particles
on break, a tick as each ball lands. Cheap, and it is what makes the loop feel
like a game rather than a simulation.

**4. The mod layer.** §5. Start with one Density mod (`Boss`: one block per row
at 6x value — pure `GameRules` values, no new seam) to prove the `GameMod` /
`ModStack` shape end to end, then one Ball collision mod to force the
`BallBehaviour` seam into existence.

**5. Export.** Desktop exe first, then Android for the S10, then touch input,
then HUD anchoring for arbitrary ratios.

Title screen, mod menu, settings, persistence, unlocking and audio are all in
`docs/ROADMAP.md` under Unscheduled. Theo has not fixed their order; ask.

---

## 9. Pause menu, Settings, and the debug menu

`Esc` -> `PauseMenu` (built in code, `scripts/ui/pause_menu.gd`), a root page
with exactly four buttons (Resume, Settings, Debug Menu, Main menu -- the
last a disabled stub, no main menu scene exists) and two sub-pages reached
from it. `_show_page` just toggles `visible` on three sibling Controls built
once in `_build_ui`; there's no navigation stack, so a page can only ever go
back to root, never to another sub-page directly. `Restart` lives on the
Debug Menu page, not root, since the root button list was specced exactly and
didn't include it.

### Settings (persisted)

The `Settings` autoload (`scripts/settings_state.gd`) holds `ui_scale`,
`screen_shake_strength`, `sfx_volume`, `music_volume` -- loaded from and saved
to `user://settings.cfg` (a `ConfigFile`) on every change, so unlike `Debug`
these survive an actual game restart, not just a scene reload.

- **UI scale** is applied as a uniform `Control.scale` (pivot at the origin)
  on three separate root Controls: `HUD`'s `$Root`, `PauseMenu`'s built root,
  and `DebugOverlay`'s built root. It is NOT `Window.content_scale_factor` --
  the design resolution and canvas_items/expand stretch are untouched; this
  only zooms the UI layer, and each of the three listens to
  `Settings.changed` independently rather than sharing one scaled parent.
- **SFX / Music volume** move the "SFX" / "Music" buses declared in
  `audio/bus_layout.tres` (`project.godot`'s `audio/buses/default_bus_layout`)
  via `AudioServer.set_bus_volume_db` / `set_bus_mute`. No sound files or
  `AudioStreamPlayer`s exist anywhere yet -- the buses and the sliders are
  real, there is just nothing routed through them to hear.
- **Screen shake strength** is a plumbed, unconsumed value. No screen shake
  exists (ROADMAP's "Juice" row is still unchecked); wire it in when that
  lands rather than adding a second setting then.

### Debug menu

`Esc` -> Debug Menu -> **Enable debug mode** flips the `Debug` autoload's
`enabled` flag. Everything below is gated behind it (`Game._tick_debug_input`,
`Game._unhandled_input`, `DebugOverlay._on_debug_enabled_changed`) and
otherwise inert.

### Row-shift credit

Shift+`↑` (`Game.debug_shift_rows(1)`) pulls the whole field up one row via
`GridManager.shift_up()` and increments `Game.debug_row_credit`. The next
`debug_row_credit` real round-completions (`_end_round`) shift down WITHOUT
spawning a new row or advancing `round_number` -- they spend the credit
instead, one per round, until it hits 0. Shift+`↓` does a raw shift down
(`grid.advance()`, so it CAN end the run exactly like a normal round's shift
can) and decrements credit, clamped at 0 -- there's no symmetric "debt" concept
for shifting down past 0, since only the up-shift case was specced.

### Expected-value shadows

`Game.expected_ball_count` and `Game.expected_round_number` mirror what
`ball_count` / `round_number` would be from pure normal play, with debug
actions never touching them. Both advance once per `_end_round`, unconditional
of the credit branch (i.e. a credit-consuming round still counts toward
"how many rounds you've actually played"). `debug_ball_count_delta` and
`debug_round_delta` / a direct row-credit shift touch only the real value.
`DebugOverlay.refresh_readouts` shows the expected number in parentheses only
when it differs from the real one.

### Spawn row, and grid-apply

`GameRules.spawn_row_index` (default 0) is which row `GridManager.spawn_row`
targets -- raising it just wastes the rows above as permanently-empty padding
(nothing ever back-fills them), which is a legitimate debug move for testing
near the death row without playing 20 rounds to get there. The pause menu's
grid width/height/kill-row/spawn-row fields all write straight to `rules` and
call `Game._on_debug_grid_apply`, which resets `round_number`/`ball_count`/
both expected shadows/`debug_row_credit` to their starting values, re-runs
`_layout_playfield` + `_prime_board` (this wipes the board -- `GridManager.
configure` frees every existing cell), and asks `DebugOverlay` to rebuild its
row buttons. There is no attempt to preserve the old board across a resize.

### Click/tap damage, row-clear, clear-all

`Game.debug_damage_at` (1 damage) / with `destroy: true` (full value, via
`Block.hit(block.value)`) is reached from a left-click on a block
(`_unhandled_input`) or a Shift+click (`Input.is_action_pressed(
"debug_shift_hold")` at the same point). `GridManager.clear_row` / `clear_all`
(new this pass) do the same through `Block.hit()`, which is why none of this
inflates `round_damage`/`total_damage` -- those only move through
`Ball.block_damaged`, which nothing here emits.

### Touch: NOT verified

The on-screen D-pad (presses the same `debug_up`/`down`/`left`/`right`
actions a keyboard would via `Input.action_press`), the center shift-toggle
button, and the two-finger-tap destroy gesture (`Game._handle_debug_touch`,
tracking concurrent `InputEventScreenTouch` indices) are built to spec but
**never run on real touch hardware** -- there's no Android/touch build yet
(§8 task 5, ROADMAP.md). Treat the feel of both as unverified until someone
tries them on an actual device.

---

## 10. Skins and visual feedback

### Skins (test swatches, not shipped content)

`Skins` (autoload, `scripts/skins.gd`) holds a handful of ball / background /
block colour treatments -- session-only, like `Debug`, not persisted like
`Settings`, since "which swatch was I comparing" isn't worth remembering
across a restart and there's no art to skin yet, just recolours. Cycle
buttons live on the Debug Menu page. `Palette.health_color()` now reads
`Skins.block().ramp` instead of a hardcoded `ROYGBIV` (`ROYGBIV` is still
there, just as the default skin's own ramp); `Ball`, `Shooter` and
`Game._draw()`'s background read `Skins.ball()` / `Skins.background()` the
same way, and `Block` re-`_refresh()`es on `Skins.changed` so existing blocks
on the board recolour live rather than only the next-spawned ones.

### Background grid toggle

`Settings.show_background_grid` (default on, preserving the prior always-on
look) gates the faint per-cell lines in `GridManager._draw()` -- one line per
cell edge, i.e. always 1:1 with the actual gameplay grid, never a decorative
pattern at its own scale. The death-row tint is NOT gated by this -- it's a
gameplay indicator, not decoration.

### Hit chunks / destroy fragments

`Game._on_block_damaged` spawns 3-5 `BlockChunk`s (`scripts/vfx/
block_chunk.gd`) when `is_instance_valid(block) and block.value > 0` --
i.e. the block survived. `Game._on_block_destroyed` (newly wired to
`GridManager.block_destroyed`, previously unlistened -- see the loose end
this replaces) spawns 4 `BlockFragment`s per kill. Both are plain
`Node2D.new()` + `setup()`, no `.tscn`, added under a new `Effects` node
(sibling of `Balls`/`Grid`/`Walls` in `main.tscn`) so their lifetime is
independent of the grid (which gets wiped on a debug resize) and of
`balls_root`. `Block.get_color()` / `get_size()` are the two accessors added
to feed these. "Falls to the ground" is a short local fall (gravity + fixed
lifetime), not a flight to `rules.floor_y` -- a block near the top of a
9-row board can be 1000+ px above the actual floor, and covering that in
under a second would read as a launch, not a drop.

### Balls gather instead of vanishing

`Game._on_ball_finished` no longer frees a landed ball -- it appends to
`_landed_balls` and only frees it (via `Ball.return_to`, a tweened quadratic
Bezier arc with a random height) once `_end_round` knows the shared target
(the shooter's new X). The shooter itself now `slide_to_x`s there instead of
snapping. Purely cosmetic and non-blocking -- the round state machine moves
on to AIMING immediately regardless of whether the gather animation has
finished playing.

### The +1 ball pickup drops a ball

`Game._on_pickup_collected` no longer increments `pending_balls` directly --
it spawns a `FallingBall` (`scripts/falling_ball.gd`) at the pickup's
position, and `pending_balls += 1` only happens in `_on_powerup_ball_landed`,
wired to the `FallingBall.landed` signal once it reaches `rules.floor_y`.
`FallingBall` never collides with anything; it's a plain node moving itself
down each frame.

---

## 11. Loose ends

- `icon.svg` is a placeholder. Six neon candidates are in `branding/icons/`;
  Theo picks one and it gets copied over `icon.svg`. Until then the icon is
  deliberately plain.
- No screen shake yet -- `Settings.screen_shake_strength` is plumbed and
  persisted, but nothing reads it. Wire it in when screen shake is built
  rather than adding the setting then.
- There is no "board cleared" handling. If every block dies, the next row still
  spawns and play continues, which is correct — but Theo's notes mention a
  milestone audio cue for a clear board, so the detection will be wanted.
- No `export_presets.cfg` yet; it is gitignored, so the first exporter will need
  to decide whether to keep it out.
- Currency pickups are requested but not started -- no economy numbers or a
  name for the currency exist yet.
- "Skins" so far are recolours (§10), not asset-based skins -- there is no
  art pipeline, and no SFX exist at all (impact VFX are done, impact SFX are
  not -- the "SFX" audio bus is real, nothing plays through it yet).
