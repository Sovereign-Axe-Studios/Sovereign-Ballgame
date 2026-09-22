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
              3. GridManager.advance() shifts every occupant down one row
              4. a Block landing in death_row() -> GAME_OVER
              5. round_number += 1, GridManager.spawn_row(round_number)
   |
AIMING      ...
```

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

- **Row 0** is the spawn row. A new row appears here every round.
- **`rules.death_row()`** (default `grid_height - 1`, the bottom row) ends the
  run. It is drawn with a red tint and a red line so it reads in play.
- The shooter sits *below* the grid, near `floor_y`, not in a grid cell.
- A block therefore survives 6 shifts on a 7-row board before it kills you.

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

Defined in `project.godot`, not read raw: `aim_left` (Left / A), `aim_right`
(Right / D), `fire` (Space), `debug_shift_down` (Down), `debug_shift_up` (Up),
`restart` (R). Mouse press-drag-release also aims and fires, via
`Game._unhandled_input` — the HUD root Control is `mouse_filter = 2` so clicks
reach it.

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

## 9. Loose ends

- `icon.svg` is a placeholder. Six neon candidates are in `branding/icons/`;
  Theo picks one and it gets copied over `icon.svg`. Until then the icon is
  deliberately plain.
- `GridManager.block_destroyed` is emitted but nothing listens. It exists for
  the juice work in task 3 and for Fracture/Infection-style mods.
- There is no "board cleared" handling. If every block dies, the next row still
  spawns and play continues, which is correct — but Theo's notes mention a
  milestone audio cue for a clear board, so the detection will be wanted.
- No `export_presets.cfg` yet; it is gitignored, so the first exporter will need
  to decide whether to keep it out.
