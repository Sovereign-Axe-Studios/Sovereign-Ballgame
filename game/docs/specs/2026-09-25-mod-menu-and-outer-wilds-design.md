# Mod menu redesign + Outer Wilds extras: design

2026-09-25. Status: approved in chat.

Builds on `2026-09-24-game-mods-design.md`. Two parts, built in this order
(each one is playable on its own):

- **A. Mod menu redesign.** A character-select grid, animated icons, and a
  ? detail panel with a live mini-game.
- **B. The Outer Wilds easter egg.** A title-screen constellation unlocks
  two mods (Wormholes, Time Rewind) and three skins (Interloper ball, Orbital
  Probe Cannon shooter, End Times background).

Build order: A1-A3, then B1 (Unlocks) and B2 (constellation), B3 Wormholes,
B4 Time Rewind, B5 skins.

---

## A. Mod menu redesign

### A1. Layout: character-select grid

`ModeSelect`'s Custom page is replaced by a grid:

- One row per `GameMod.Category`, in enum order. Each row has a neon header
  (`ArcadeUI` style, category name in caps) and then square tiles in an
  `HFlowContainer`.
- The first tile is always **None** (dimmed icon). Selecting is radio-style
  per row, and the lit tile is the pick.
- Tile = icon (the mod's preview drawn at `t = 0`) + name, with a small **?**
  button in the top-right corner.
- `available = false` tiles (Reinforcements) stay visible but disabled, with
  their description as the tooltip.
- **Locked** tiles (see B1) show a dark silhouette, the name `???`, and the
  tooltip *"Look to the stars."*. The ? button is hidden and the tile can't be
  selected.
- BACK / NEXT at the bottom, as now.

The list page (curated modes) is unchanged.

**Revisit later:** once categories hold about 6-12 mods, reconsider the
category-tabs or loadout-slot layouts (both mocked up in chat on 2026-09-25).

### A2. Tile animation: `draw_preview`

`GameMod` gains:

```gdscript
## Draw a looping sketch of this mod into `rect` on `canvas` at time `t`
## (seconds). t = 0 is the static icon. Default: a plain category glyph.
func draw_preview(canvas: CanvasItem, rect: Rect2, t: float) -> void

## False = the ? panel plays draw_preview full-size instead of a live board
## (for mods a 4x5 board can't show: Lives, Modified Grid).
var live_preview: bool = true
```

- `ModPreviewIcon` (`scripts/ui/mod_preview_icon.gd`) is a `Control` that
  owns a mod instance. It calls `draw_preview` in `_draw`, and while hovered
  advances `t` and redraws each frame. When not hovered it draws `t = 0`.
- Every existing mod implements `draw_preview`. These are the sketches from
  the 2026-09-25 mockup: Wrap (a ball crossing the wall and reappearing),
  Snowball (a growing ball with a +N), Circles (a square rounding off),
  Tilt (a block rotating to 15°), Spread (a fan of shots from the shooter),
  Boss (one big block among empty cells), Grid (a grid growing columns and
  rows), Lives (hearts ticking down), Reinforcements (static placeholder).

### A3. The ? detail panel: live mini-game

- The ? button opens an overlay panel: name, category, description, and a
  preview area of about 420×560.
- **Live preview** (`scripts/ui/mod_live_preview.gd`): a `SubViewportContainer`
  containing a `SubViewport` that runs a stripped-down board:
  - A real `GridManager`, `Ball` and `Block`, a small `GameRules` (4 wide,
    5 tall, bigger cells), `install([fresh mod instance])`.
  - Walls built the same way as `Game._build_walls`. To share that code
    rather than copy it, `_build_walls` moves into a small static helper
    (`scripts/playfield_walls.gd`) that `Game` and the preview both call.
  - Scripted aim: a fixed, repeating list of aim angles tuned to show the
    effect, firing 3 balls every ~1.5 s. The board refills when it's empty.
  - No HUD, pause, debug, pickups, or loss (blocks never shift down).
- If `live_preview == false`, the panel draws the mod's `draw_preview`
  full-size, looping.
- Esc or a click outside closes the panel.

---

## B. The Outer Wilds easter egg

### B1. Unlocks (persisted)

- A new autoload, **`Unlocks`** (`scripts/unlocks_state.gd`), saved to
  `user://unlocks.cfg` on every change. This is a sixth lifetime: progress,
  persisted, separate from `Settings` (preferences).
- API: `is_unlocked(id: StringName) -> bool`, `unlock(id)`, `relock_all()`,
  and `signal changed`. One id so far: `&"outer_wilds"`.
- `GameMod.locked_by: StringName` (empty = always available). A mod is
  selectable when `available and (locked_by == &"" or Unlocks.is_unlocked(locked_by))`.
- The skin classes (`BallSkin`, `BackgroundSkin`, `LauncherSkin`) get the same
  `locked_by` field. The Skins pickers (pause menu, Asset Viewer) show locked
  skins as disabled `???` chips with the same tooltip. `Skins.set_*` refuses a
  locked index.
- `Run.start` / `GameRules.install` skip locked mods with a warning, the same
  as unavailable ones.
- Debug Menu: **Unlock all** and **Re-lock all** buttons.

### B2. The constellation (title screen)

- `scripts/title/nomai_constellation.gd`: a `Node2D` drawn over the title
  starfield and under the UI. The data is `const POINTS: Array[Vector2]`
  (normalized 0-1 within the constellation's rect) and
  `const EDGES: Array[Vector2i]`, hand-placed to trace the outline of the
  Nomai emblem Theo supplied: the outer ring of four curved arms and the
  central diamond mask. Roughly 20 points.
- Placement: centred horizontally, spanning roughly y 80-760 (behind the title
  text). The title labels already ignore the mouse, so clicks reach the stars.
- **Tell:** the emblem stars have a faint warm tint (Nomai amber) and twinkle
  at about half the ambient stars' rate. On hover a star pulses and grows
  slightly. The click radius is generous (~28 px).
- **Linking:** click to light a star, in any order. An edge draws (a thin
  amber line, fading in) once both of its endpoints are lit. There's no way to
  fail. Lit state resets when the title screen is left.
- **Completion:** when the last star lights, all edges flash, the emblem
  blooms (scales up about 5% and brightens over ~1.5 s), and a banner reads
  **OUTER WILDS EXTRAS UNLOCKED** with the five items listed. Then
  `Unlocks.unlock(&"outer_wilds")`.
- **Already unlocked:** the constellation draws fully linked but dim, as a
  quiet trophy, and isn't clickable.

### B3. Wormholes (WALL mod)

`scripts/mods/wall/wormholes.gd`, `locked_by = &"outer_wilds"`.

- A **black hole** and a **white hole**, one-way, like the game: a ball whose
  centre comes within `CAPTURE_RADIUS` of the black hole reappears at the
  white hole with the same heading, pushed out past `EXIT_RADIUS` so it
  can't be recaptured. One trip per `REENTRY_COOLDOWN` seconds per ball.
- Placement: two different random **empty** cells between row 1 and
  `death_row - 1`. They relocate every `RELOCATE_ROUNDS = 3` rounds, and
  immediately if a block shifts into either cell.
- Visuals: the black hole is a dark disc with a swirling accretion ring; the
  white hole is a bright disc with outward rays. Drawn by a `Node2D` the mod
  adds.
- **New hooks on `GameMod`, called for every installed mod:**
  - `on_run_start(rules, game)`: after the first layout, so mods can add
    nodes under `game.effects_root`.
  - `on_round_end(rules, game)`: after `advance()`, before AIMING.
  - `on_ball_step(rules, ball)`: after every `Ball` physics substep. The
    wormhole capture lives here. Routed through `GameRules` like every other
    hook: WALL owns it, and it's a single direct call.
- Game constants: `CAPTURE_RADIUS`, `EXIT_RADIUS`, `REENTRY_COOLDOWN`,
  `RELOCATE_ROUNDS`, all at the top of `wormholes.gd`.

### B4. Time Rewind (BALL_COLLISION mod)

`scripts/mods/ball_collision/time_rewind.gd`, `locked_by = &"outer_wilds"`.

- `REWIND_AFTER = 22.0` seconds after the round's first shot, every live ball
  starts rewinding. Shots not yet fired are cancelled (`game` stops firing).
- A rewinding ball plays its recorded path backwards at `REWIND_SPEED = 2.0`
  times normal speed, collides with nothing, and deals no damage. When it
  reaches its start point it finishes normally (`finished` signal), so the
  round resolves the usual way. Damage already dealt is not undone.
- Path recording: `Ball` records a point per physics frame (only when the
  BALL_COLLISION mod asks for it, via `wants_path_recording(rules) -> bool`,
  so ordinary runs pay nothing). Recording is capped at 22 s x 120 Hz.
- Visuals: rewinding balls get a blue tint, and one expanding ring pulses from
  the shooter at the moment of rewind.
- **New hook** (BALL_COLLISION owns it): `on_firing_tick(rules, game,
  seconds_since_first_shot)`, called by `Game._tick_firing` each frame while
  FIRING. `Game` gains `stop_firing()`, and `Ball` gains `start_rewind()`.

### B5. Skins

All three have `locked_by = &"outer_wilds"`. `Skins` selection stays
session-only.

- **Interloper ball** (ball skin): a pale ice-white core with a cyan comet
  tail, plus an occasional green ghost-matter fleck. `BallSkin` gains
  `trail: bool` and `trail_color`. When `trail` is set, `Ball` keeps a short
  position history (about 10 points) and draws a tapering tail behind the
  body.
- **Orbital Probe Cannon** (launcher skin): a new `LauncherShape.PROBE_CANNON`
  drawn by `Shooter` as a segmented barrel with three ring bands and a glowing
  muzzle, with a brief muzzle flash on each shot (`Shooter.flash()`, called
  from `Game._spawn_ball`).
- **End Times** (background skin): a new `BackgroundSkin` field,
  `animated: bool`. When set, `Game` adds an `EndTimesBackground` node
  (`scripts/vfx/end_times_background.gd`) behind the playfield instead of the
  flat fill. Cycle (`CYCLE_SECONDS = 60`): about 80 stars. Over the cycle they
  blink out one by one, about 1 in 6 going supernova first (a bright flare
  plus an expanding ring). When the last one dies there's a big-bang white
  flash from the centre, then a new set streams outward from the centre and
  eases into random resting positions. Repeat. This is the game background
  only; the title keeps its own starfield (that's where the constellation
  lives).

---

## Verification

- `check_mods` also checks: every mod's `draw_preview` runs at t = 0 and 1.5
  without error on a scratch `Control`, and locked mods are skipped by
  `install` while locked.
- Headless loads: `main.tscn`, `mode_select.tscn`, and `main_menu.tscn` with
  Outer Wilds both locked and unlocked.
- A scratch auto-fire harness plays Wormholes (count teleports) and Time
  Rewind (confirm the rewind starts at 22 s, fire stops, the round resolves)
  to game over.
- Not verifiable headless, so Theo checks by eye: the tile icons and hover
  animations, the ? live preview, the constellation placement against the
  title, the completion bloom, and all three skins.

## Docs

CLAUDE.md: `Unlocks` lifetime, new hooks, `draw_preview`. HANDOFF: new
section. ROADMAP: mod menu and unlocking items updated.
