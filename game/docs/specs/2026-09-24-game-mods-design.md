# Game mods: design

2026-09-24. Status: approved in chat, awaiting Theo's read-through.

Covers ROADMAP "Modularity basics": one example mod per category, the
`GameMod` seam, how mods are registered, and the flow for picking a mode.
Supersedes the `GameMod` / `ModStack` proposal in HANDOFF §5 where the two
differ.

---

## Goals

- One working mod in every GDD category except Spawn direction, which gets a
  greyed-out placeholder (Reinforcements).
- Mods can be added and removed as units: **one file per mod**, plus one line
  in `cfg.gd`.
- Debuggable: a breakpoint or stack trace always lands in the mod file or the
  game logic that called it. **Hooks are direct, typed method calls**: no
  `call("name")`, no `has_method`, no signals as hooks.
- Mod values are Ctrl+click-reachable from anywhere through `Cfg`.
- Title screen: **Quick Play** (no mods) and **Play**, which opens a mode
  select screen with 2 curated modes and a Custom builder.

## Non-goals (this pass)

- Editing mod values (the GDD's "X") from the UI. Values are constants in the
  mod file.
- More than one mod per category.
- Persisting the chosen mods, unlocking, mod icons.
- Replacing the Asset Viewer's Game Mods stub.
- Any Spawn direction behaviour.

---

## 1. Files

```
scripts/mods/game_mod.gd              GameMod base class: category, hooks, defaults
scripts/mods/shot_spread/spread.gd
scripts/mods/ball_collision/snowball.gd
scripts/mods/wall/wrap_around.gd
scripts/mods/spawn_direction/reinforcements.gd   available = false, no logic
scripts/mods/shape/circles.gd
scripts/mods/rotation/rotated.gd      "5° x N"
scripts/mods/density/boss.gd
scripts/mods/grid/modified_grid.gd
scripts/mods/loss/lives.gd
scripts/modes/curated_modes.gd        the 2 placeholder curated modes
scripts/run_state.gd                  Run autoload: the chosen mode for this session
scripts/mode_select.gd + scenes/mode_select.tscn   Play -> mode list -> Custom
scripts/tools/check_mods.gd           headless smoke check
```

### One mod = one file

Each mod file `extends GameMod`. The top of the file holds its tunables as
`const`s with `##` rationale comments, in the same style as
`scripts/config/*.gd`. Hook overrides go below. Example shape:

```gdscript
extends GameMod
## Boss -- one block per row, at 6x the usual row value.

## How many units the single block carries. 6 = "6x strength" in the GDD.
const UNITS := 6

func _init() -> void:
	category = Category.DENSITY
	display_name = "Boss"
	description = "One block per row at %dx strength." % UNITS

func apply(rules: GameRules) -> void:
	rules.max_units_per_cell = maxi(rules.max_units_per_cell, UNITS)

func row_units(_rules: GameRules, _round_number: int) -> int:
	return UNITS

func open_slots(rules: GameRules) -> int:
	return rules.grid_width - 1
```

**CLAUDE.md rule amendment:** gameplay numbers live in `scripts/config/*.gd`,
`scripts/game_rules.gd`, **or as `const`s at the top of the mod file that owns
them**.

### Cfg is the registry

`cfg.gd` gains a Mods section:

```gdscript
# --- Mods -------------------------------------------------------------------
const Spread := preload("res://scripts/mods/shot_spread/spread.gd")
const Boss := preload("res://scripts/mods/density/boss.gd")
# ... one line per mod
const MODS: Array[GDScript] = [Spread, Snowball, WrapAround, Reinforcements,
	Circles, Rotated, Boss, ModifiedGrid, Lives]
```

- `Cfg.Boss.UNITS` is typed, autocompletes, and Ctrl+click jumps to the
  constant in `boss.gd`.
- `Cfg.MODS` is the one list the mode screens read. There is no folder
  scanning.
- **Removing a mod** means deleting its file and its `cfg.gd` line (plus any
  curated mode that names it). If the line is missed, the parse error on that
  exact line is the guard. There is no runtime `ResourceLoader.exists` guard,
  because it would cost typing and click-through.
- **Adding a mod** means the file plus one line in `cfg.gd`.
- Code outside a mod reads **live** values from `rules` or the mod instance,
  not `Cfg`. `Cfg.<Mod>.*` is for showing defaults (descriptions, the Custom
  screen).

`GameRules` must not reference `Cfg` (see the header of `cfg.gd`), and mod
files don't need to either.

---

## 2. GameMod and how GameRules calls it

```gdscript
class_name GameMod
extends Resource

enum Category { SHOT_SPREAD, BALL_COLLISION, WALL, SPAWN_DIRECTION,
	SHAPE, ROTATION, DENSITY, GRID, LOSS }

var category: Category
var display_name: String
var description: String
var available := true          # false = listed but greyed out

func apply(rules: GameRules) -> void  # value tweaks, once per run
func status_text(rules: GameRules) -> String   # HUD line, "" = none
# ...plus the hooks below, each defaulting to stock behaviour
```

**Composition, not subclassing.** `GameRules` keeps
`var _slots: Dictionary  # Category -> GameMod`. Every category starts filled
with one shared plain `GameMod` instance, whose hooks return the stock
behaviour. `GameRules.install(mods: Array[GameMod])` puts each mod in its slot
and calls `apply(self)`. A second mod in the same category replaces the first
and prints a warning.

Every existing virtual hook on `GameRules` becomes a single direct call into
the slot that owns it, e.g.:

```gdscript
func row_units(round_number: int) -> int:
	return _slots[GameMod.Category.DENSITY].row_units(self, round_number)
```

The stock implementations move to `GameRules.default_row_units()` etc., and
the base `GameMod` calls those. The call stack for a modded call is then
`grid_manager.gd:spawn_row -> game_rules.gd:row_units -> boss.gd:row_units`.
For an unmodded call it is `... -> game_mod.gd:row_units ->
game_rules.gd:default_row_units`.

This replaces "subclass GameRules" as the mod mechanism (CLAUDE.md and HANDOFF
§5 get updated to match). `GameRules` stays the only thing gameplay reads.

### Hook table: which category owns which hook

| Hook (on GameMod) | Owner | Called from |
|---|---|---|
| `apply(rules)` | every mod | `GameRules.install` |
| `row_units`, `unit_value`, `open_slots` | DENSITY | `GridManager.spawn_row` (via rules, as today) |
| `shots_for_round(rules, ball_count)` | BALL_COLLISION | `Game` (as today) |
| `damage_for(rules, ball) -> int` | BALL_COLLISION | `Ball` block contact; default `rules.ball_damage` |
| `on_wall_hit(rules, ball, collision) -> bool` | WALL | `Ball` wall contact; `true` = handled, skip the bounce |
| `configure_block(rules, block)` | SHAPE, then ROTATION | `GridManager._place_block`, after `setup()` |
| `death_row(rules)` | LOSS | as today |
| `on_death_row_reached(rules, blocks) -> bool` | LOSS | `GridManager.advance`; `true` = run continues |
| `status_text(rules)` | every mod | HUD |

New ball state: `Ball.bounces: int`, incremented on every bounce (wall or
block) after damage is dealt. It's generic, so later mods (Fracture, Buildup)
can reuse it.

### Invincible folds into the loss hook

`GridManager.advance` collects the Blocks that landed on the death row this
shift into an array instead of setting `lost` inline. If the array is
non-empty:

1. If `Debug.invincible` is on, destroy them through `Block.hit(block.value)`
   (today's behaviour) and continue. Debug always wins, independent of mods.
2. Otherwise, ask `rules.on_death_row_reached(blocks)`. The stock answer is
   `false` (game over). Whoever answers `true` is responsible for clearing
   the blocks.

---

## 3. The mods

Numbers are each file's starting `const`s. Theo tunes them.

| Category | File | Behaviour | Consts |
|---|---|---|---|
| Shot spread | `spread.gd` | `apply` sets `rules.random_rotate_value_deg` (already live in `_spawn_ball`) | `SPREAD_DEGREES = 6.0` |
| Ball collision | `snowball.gd` | `shots_for_round` = `ceil(ball_count / BALL_DIVISOR)`; `damage_for` = `rules.ball_damage + ball.bounces * DAMAGE_PER_BOUNCE` | `BALL_DIVISOR = 3`, `DAMAGE_PER_BOUNCE = 1` |
| Wall | `wrap_around.gd` | Side walls only (collision normal mostly horizontal): mirror the ball's x about the playfield centre, keep its direction, and return `true`. The top wall still bounces | `SIDE_NORMAL_THRESHOLD = 0.5` |
| Spawn direction | `reinforcements.gd` | `available = false`; description says "coming soon" | none |
| Shape | `circles.gd` | `block.set_shape(Block.Shape.CIRCLE)`: a `CircleShape2D` collider and a circle `_draw` | none |
| Rotation | `rotated.gd` | `block.rotation_degrees = STEP_DEGREES * N`. Shrinks the body by `1 / (cos θ + sin θ)` so rotated blocks still fit their cell, and counter-rotates the value label so it reads upright | `STEP_DEGREES = 5.0`, `N = 3` |
| Density | `boss.gd` | 1 block per row with `UNITS` units (see the example above); the pickup still spawns in an empty slot | `UNITS = 6` |
| Grid | `modified_grid.gd` | `apply` sets `grid_width` / `grid_height` (layout already handles other sizes) | `WIDTH = 9`, `HEIGHT = 11` |
| Loss | `lives.gd` | Per-run `lives_left`. `on_death_row_reached` costs **one life per shift** (not per block), destroys those blocks via `hit()`, and returns `lives_left > 0`. `status_text` shows "LIVES n" | `START_LIVES = 3` |

`Block` gains `enum Shape { SQUARE, CIRCLE }` plus `set_shape()`. Hit chunks
and destroy fragments stay square-based; that's fine for a test pass.

---

## 4. Run state and flow

**`Run` autoload** (`scripts/run_state.gd`, session-only, the fifth lifetime
alongside Cfg / Debug / Settings / Skins):

```gdscript
var mode_name: String = "Quick Play"
var mod_scripts: Array[GDScript] = []    # scripts, not instances
func start(name: String, mods: Array[GDScript]) -> void   # sets both, loads the game scene
```

`Run` stores **scripts**, not instances. `Game._ready` does
`rules.install(Run.mod_scripts.map(func(s): return s.new()))`, so stateful mods
(Lives) start fresh on every run, including restarts with **R**.

### Title screen

`▶ QUICK PLAY` (new, top: `Run.start("Quick Play", [])`), `▶ PLAY` (now opens
Mode Select), Settings, Game States, Asset Viewer.

### Mode Select (`scenes/mode_select.tscn`, built in code, arcade style)

- **Page 1, the mode list:** vertical list of big buttons. The two curated
  modes (name plus a one-line list of their mods), then `CUSTOM`, then `BACK`.
  A curated button starts the run immediately.
- **Page 2, Custom:** one row per category in `Category` order, each row a
  chip picker (`None` + that category's mods from `Cfg.MODS`, the same chip
  style as the Skins page). Unavailable mods are disabled chips with their
  description as the tooltip. The selected chip's description shows under the
  row. `BACK` returns to page 1, `NEXT` does `Run.start("Custom", picks)`.
- Esc steps back a page, then to the title (same as the pause menu).

### Curated modes (`scripts/modes/curated_modes.gd`)

Placeholders, but playable:

- **Boss Rush**: Boss + Lives
- **Tilt**: Spread + Rotated + Wrap Around

Stored as `{name, mods: Array[GDScript]}` built from `Cfg.<Mod>` references (a
`static func all()`, since the `Cfg` autoload isn't a const expression).

### In game

- The HUD shows the non-empty `status_text()`s (e.g. "LIVES 2").
- The pause menu's root page shows the mode name and its mods' display names.
- The Debug Menu's grid apply keeps working, writing over whatever Modified
  Grid set.

---

## 5. Errors

- A duplicate category in an install: the last mod wins, with `push_warning`.
- A deleted mod file: a parse error at its `cfg.gd` / `curated_modes.gd` line.
  This is intentional.
- A mod with `available = false` passed to `install` (shouldn't happen via the
  UI): skipped with a warning.

## 6. Verification

- `scripts/tools/check_mods.gd` (`godot --headless -s`): for every script in
  the mods list (it preloads `cfg.gd` directly, since autoloads don't exist in
  `-s` mode), instantiate it, install it on a fresh `GameRules`, call each
  DENSITY / `shots_for_round` hook once, and check the category is set and
  unique per mod. Exits non-zero on failure.
- Headless load of `main.tscn` and `mode_select.tscn` with no errors.
- Manual play: Quick Play, each curated mode, and a Custom run of each mod on
  its own for a few rounds. With Lives, lose a life and see the HUD tick down,
  then reach game over.

## 7. Docs

CLAUDE.md (the numbers rule, the mod mechanism, the Run lifetime), a new
HANDOFF section (the mod layer as built, plus how to add a mod: file, `cfg.gd`
line, optionally a curated mode), HANDOFF §5 marked superseded where it
differs, and ROADMAP "One example mod per category" ticked with Spawn
direction noted as deferred.
