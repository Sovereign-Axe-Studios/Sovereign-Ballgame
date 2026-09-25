# CLAUDE.md — Sovereign Ballgame

Read `docs/HANDOFF.md` before your first change. It has the current state, the
data model, and the ordered next tasks. `docs/ROADMAP.md` is the build order.

## What this is

A Ballz-style brick breaker in **Godot 4.7**, portrait **1080x2000** (1920 of
play area, an 80px footer for the hint text -- see HANDOFF §11), targeting
desktop and an S10-class Android phone. `run/main_scene` is
`scenes/main_menu.tscn` (title screen); the actual game is
`scenes/main.tscn`, reached via **Quick Play** or **Play** → Mode Select. Repo root is this
folder; the Godot project root is the same folder.

## The one architectural rule

**No gameplay number is written anywhere but `scripts/config/*.gd`,
`scripts/game_rules.gd`, or the `const`s at the top of the mod file that owns
it (`scripts/mods/<category>/*.gd`).**

The numbers — and the rationale behind each one — live in
`scripts/config/*.gd`, one small file per domain (`board.gd`, `spawning.gd`,
`ball.gd`, `wall_corners.gd`, `shooter.gd`, `loss.gd`), indexed by the `Cfg`
autoload (`scripts/cfg.gd`). `GameRules` is a `Resource` that preloads those
same domain files directly for its `@export` defaults, plus the mod hooks
(`row_units`, `open_slots`, `shots_for_round`, `damage_for`, `on_wall_hit`,
`configure_block`, `on_death_row_reached`...).
Every gameplay script receives a `GameRules` instance and reads from it —
`Cfg` is for anything else that wants a quick constant without a `GameRules`
instance in hand. The whole point of the project is the mod layer, and a
magic number in `ball.gd` is a mod that can never exist.

**Mods are composition, not subclassing.** `GameRules.install()` puts one
`GameMod` per category into a slot, and every hook on `GameRules` is one
direct, typed call into the slot that owns it (an empty slot is a plain
`GameMod`, whose hooks hand back to `GameRules.default_*`). Keep hooks that
way: no `call("name")`, no `has_method`, no signals as hooks. Direct calls are
what keep Ctrl+click and the debugger's call stack pointing at the right mod.
To add a mod: one file under `scripts/mods/<category>/` that `extends
GameMod`, plus one line in `cfg.gd`'s Mods section (preload + `MODS`). Code
outside the mod reads LIVE values from `rules` or the mod, not
`Cfg.<Mod>.*`, which are defaults for display only. Full design:
`docs/specs/2026-09-24-game-mods-design.md`.

If you need a new constant: add it to the right domain file in
`scripts/config/`, re-export it flat in `cfg.gd` (alphabetical within its
domain group), and if gameplay needs to read it per-run, add a matching
`@export` to `GameRules` that defaults from the domain constant. See
`scripts/cfg.gd`'s header comment for why `GameRules` preloads the domain
files directly instead of reading through the `Cfg` autoload.

Runtime overrides go on the live `GameRules` instance (`Game.rules`), never
on `Cfg`: the Debug Menu's grid and fragment fields write straight to
`rules`, and mods do the same (`apply()`). `Cfg` is shipped defaults only; session
flags live on the `Debug` autoload. Don't add a separate `tuned()` /
`set_tuned()` layer beside `GameRules`, because `GameRules` already is that
layer.

## Git — Theo commits, you do not

Theo uses GitHub Desktop and does his own committing, branching and pushing.

- **Never run** `git commit`, `git push`, `git branch`, `git checkout -b`, or
  anything that rewrites history.
- Instead: say which files changed and propose a commit message. He takes it
  from there.
- **Never add `Co-Authored-By: Claude` or similar trailers** to commit messages
  you propose.
- Repo identity is already set locally: `theo-sovereignaxe
  <theo.sovereignaxe@gmail.com>`. Do not change it.
- `git status`, `git diff` and `git log` are fine and encouraged.

## Code conventions

- Typed GDScript throughout: `func f(x: int) -> void`, `var v: float = 0.0`,
  `:=` where the type is obvious.
- **Tabs** for indentation (Godot standard), LF endings (enforced by
  `.gitattributes`).
- `##` doc comments on every class and every non-obvious function. Comments
  explain *why*, not *what* — the existing files set the tone, match it.
- `gdlint` must pass. Config in `.gdlintrc`: max line length 120,
  `class-definitions-order` disabled. `pip install "gdtoolkit==4.*"` then
  `gdlint scripts/*.gd`.
- Section banners (`# ---- spawning`) separate concerns in longer files.

## Things that are the way they are on purpose

- **The ball is a `CharacterBody2D`, not a `RigidBody2D`.** We want identical
  bounces every time — no restitution drift, no sleeping bodies, no gravity
  surprises. `Ball._physics_process` steps the frame's travel manually and
  consumes it across each bounce. Do not "simplify" this to a RigidBody.
- **Physics runs at 120 Hz** (`project.godot`). Balls move ~1750 px/s; a lower
  tick rate tunnels them through blocks.
- **Walls, ceiling and floor are built in code** (`Playfield.build_walls`, shared by `Game` and the ? panel's `ModLivePreview`) from
  `GameRules`, not placed in `main.tscn`. Grid-shape and wall mods need to move
  them, and a scene-placed wall can't be moved by a rules change.
- **The floor is a Y comparison, not a collider.** Crossing it ends the ball.
- **`ball_fire_interval` defaults to 0.09s**, not the 1.0s in Theo's original
  notes. Deliberate — see HANDOFF. Do not "fix" it back.
- **Row 0 is always clear.** `Game._end_round` (and `Game._ready`, once) calls
  `GridManager.spawn_row` *before* `advance()`, not after — the fresh row gets
  carried down to row 1 by the same shift, so row 0 reads as empty at every
  AIMING. Do not reorder this back to shift-then-spawn.
- **Default grid is 7×9**, matching the reference game — not 7×7.
- **Arrow keys are debug-only.** Aiming is A/D-only (`aim_left`/`aim_right`);
  the raw arrows drive `debug_left/right/up/down`, active only while
  `Debug.enabled`. Don't rebind arrows back onto aiming.
- **`Debug` (autoload) is session-only state, not per-run state.** It
  survives a scene reload on purpose — re-enabling it after every restart
  while testing would be its own friction. Everything that IS per-run (row
  credit, the "expected" shadow counters) lives on `Game` instead.
- **`Settings` (autoload) is persisted, unlike `Debug`.** It's user
  preferences (UI scale, screen shake strength, SFX/music volume, background
  grid), saved to `user://settings.cfg` on every change — three different
  autoloads, three different lifetimes, on purpose: `Cfg` (shipped
  defaults), `Debug` (session), `Settings` (persisted).
- **`Skins` (autoload) is a fourth lifetime: session-only test swatches.**
  A few alternate ball/background/block colour treatments to compare from
  the Debug Menu — not shipped content (no art assets exist), so it doesn't
  persist like `Settings` does. `Palette.health_color()` reads the active
  block skin's ramp; don't reintroduce a hardcoded ROYGBIV read anywhere.
- **VFX nodes (`scripts/vfx/*.gd`, `falling_ball.gd`) have no `.tscn`.**
  `.new()` + a `setup()` call, same as the debug/pause UI — one more thing
  that doesn't need a hand-written scene to get wrong.
- **Grid-line positions are rounded to the nearest pixel.** An axis-aligned
  1px line at a fractional pixel offset anti-aliases across two rows at half
  opacity each — at low alpha that reads as "missing", which is a real bug
  this fixed, not just a style choice. Don't remove the `roundf()` calls in
  `GridManager._draw()`.
- **The shooter slides on the FIRST ball landing, not at round end.**
  `Game._on_ball_finished` calls `shooter.slide_to_x` the instant
  `_has_landing` first becomes true. Don't move that call back into
  `_end_round` — the whole point was to react immediately.
- **`Skins.return_mode` decides who moves when, not just how.** STICK_*
  balls stay in `_landed_balls` until `_end_round`; MOVE_TO_SHOOTER and
  LINE_UP move a ball inside `_on_ball_finished` itself and never touch
  `_landed_balls`. Adding a new mode means deciding which of those two paths
  it belongs to.
- **`shooter.active` no longer goes false during FIRING.** It keeps showing
  the aim line at the angle it just fired. Input is gated by `Game.state`,
  not by `active`, so this doesn't let the player re-aim mid-round — don't
  reintroduce `shooter.active = false` in `_begin_firing` to "fix" this.
- **A drag release past `max_aim_degrees` cancels the shot.** Checked via
  `Shooter.raw_aim_degrees` (unclamped) against the SAME limit `set_aim`
  clamps to — there's no separate "minimum angle" constant.
- **`Debug.invincible`** makes `GridManager.advance()` destroy (via the
  normal `Block.hit()` path, not `queue_free()`) a Block that reaches the
  death row instead of returning `lost = true`. It's independent of
  `Debug.enabled` — a testing safety net, not part of the enable-debug-mode
  feature set.
- **Pause/debug UI is built in code**, not laid out in `.tscn` — see
  `scripts/ui/pause_menu.gd` / `debug_overlay.gd`. Same rationale as
  `Playfield.build_walls`: this UI depends on `rules` (row count, cell geometry)
  and has to rebuild itself when a debug grid-size apply changes them.
- **The pause menu is paged, not one flat panel**: root (Resume / Settings /
  Debug Menu / Skins / Main menu) with the latter three each their own page.
  Keep new pause-menu content on the right page rather than growing the root.
- **`Run` (autoload) is a fifth lifetime: the session's chosen mode.** It
  stores mod SCRIPTS, not instances. `Game._ready` makes fresh instances
  per run (`Run.make_mods()`), so an R restart keeps the mode but resets
  stateful mods like Lives. Start a run through `Run.start()`, not
  `change_scene_to_file(main.tscn)`, or the previous mode leaks in.
- **`Debug.invincible` beats any LOSS mod.** `GridManager.advance` checks it
  before asking `rules.on_death_row_reached`.
- **`Unlocks` (autoload) is a sixth lifetime: earned progress, persisted** to
  `user://unlocks.cfg`, separate from `Settings` so resetting one never
  touches the other. `GameMod.locked_by` and every skin record's `locked_by`
  name an unlock id; locked mods can't be installed, and locked skins can't
  be selected through any `Skins.set_*`. The Debug Menu has Unlock all /
  Re-lock all. Autoload order matters: `Unlocks` loads before `Skins`.
- **Field hooks take a `Playfield`, never a `Game`** (`on_run_start`,
  `on_round_end`), so the ? panel's live mini-board can run the same mod. The
  exception is `on_firing_tick(rules, game, seconds)`, which needs the real
  round (Time Rewind), and that mod sets `live_preview = false`.
  `on_run_start` runs again after a Debug Menu grid apply, so a mod that adds
  nodes must reuse them rather than add a second set.
- **`rules.play_left` / `play_right` are runtime layout, not tunables.** Set
  by whoever lays the board out. Wall-aware code (corner jitter, Wrap Around)
  reads them, never the 1080 viewport width, so it works on the preview board.
- **Every mod implements `draw_preview(canvas, rect, t)`** with the
  `PreviewDraw` helpers: t = 0 is its tile icon, hover animates it.
  `check_mods` draws each one, so a broken sketch fails loudly.
- **Tool checks are scenes, not `-s` scripts.** `-s` compiles before autoloads
  are registered, and `Ball`/`Block` read `Skins`, so a `-s` script that
  touches them fails to compile. See `scenes/tools/check_mods.tscn`.
- **`run/main_scene` is `scenes/main_menu.tscn`, not `scenes/main.tscn`.**
  The title screen's Quick Play / Play (via Mode Select) buttons start the
  game. Don't point it back at the
  game scene directly — Main menu (pause menu) and the title screen's own
  buttons both assume the title screen is the scene tree's actual root.

## Verification

Mod registry: `godot --headless --path . scenes/tools/check_mods.tscn`
(exits non-zero on failure). Static parsing is not enough. `gdparse` and `gdlint` catch syntax, not the
things that actually break here (collision layers, node paths, signal
signatures, balls wedging between blocks). **Run the project** — `godot
--path . ` or F5 in the editor — and play a few rounds before calling
something done.

## Layout

```
project.godot        Godot 4.7, portrait, GL compatibility, 120 Hz physics
icon.svg             placeholder; neon options live in branding/icons/
branding/icons/      six neon icon candidates, Theo picks one
scenes/              main (the game), main_menu, asset_viewer, ball, block, pickup
scripts/main_menu.gd    title screen
scripts/asset_viewer.gd tabbed Skins/Modes/Audio browser
scripts/config/      Cfg's domain files — the numbers, one file per domain
scripts/cfg.gd       Cfg autoload — thin index over scripts/config/*.gd, and
                     the mod registry (Mods section, Cfg.MODS)
scripts/mods/        GameMod base + one file per mod, by category folder
scripts/modes/       curated modes (CuratedModes.all())
scripts/run_state.gd Run autoload — the chosen mode for this session
scripts/unlocks_state.gd Unlocks autoload — persisted unlocks (user://unlocks.cfg)
scripts/playfield.gd Playfield — what field hooks get; shared wall builder
scripts/title/       nomai_constellation.gd — the title-screen easter egg
scripts/ui/mod_preview_icon.gd, mod_live_preview.gd, preview_draw.gd
                     mod tile icons, the ? panel's live board, sketch helpers
scripts/vfx/end_times_background.gd  the End Times animated background
scripts/mode_select.gd  Play -> curated list / Custom mod picker
scripts/tools/ + scenes/tools/  check_mods (headless registry smoke check)
scripts/debug_state.gd  Debug autoload — the debug-mode on/off flag
scripts/settings_state.gd  Settings autoload — persisted user prefs
scripts/skins.gd     Skins autoload — ball/background/block test swatches
scripts/vfx/         hit chunks + destroy fragments (no scene, built in code;
                     fragment cols/rows come from GameRules/Cfg.Juice)
scripts/falling_ball.gd  the +1 ball pickup's cosmetic drop-to-floor
scripts/ui/          pause menu (paged) + debug overlay (built in code, not .tscn),
                     arcade_ui.gd (title/Mode Select button + chip styles)
audio/bus_layout.tres  Master -> Music, SFX buses
scripts/             see docs/HANDOFF.md for the file-by-file map
docs/HANDOFF.md      current state + next tasks  <- start here
docs/ROADMAP.md      full build order, what's done marked
```
