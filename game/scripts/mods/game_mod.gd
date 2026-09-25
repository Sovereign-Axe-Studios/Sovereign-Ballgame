class_name GameMod
extends Resource
## One game mod. Each mod is its own file under `scripts/mods/<category>/`,
## `extends GameMod`, keeps its tunables as `const`s at the top, and overrides
## only the hooks its category owns. Register it with one line in `cfg.gd`'s
## Mods section -- `Cfg.MODS` is the list the mode screens read.
##
## `GameRules` holds one mod per category (its "slot") and every hook on
## `GameRules` is a direct call into the slot that owns it -- see the hook
## table in docs/specs/2026-09-24-game-mods-design.md. An empty slot is a
## plain `GameMod`, whose hooks below are the stock game: each just hands back
## to `GameRules.default_*`. So a stack trace always reads
## `caller -> game_rules.gd -> <the mod>.gd`, and a breakpoint in a mod file is
## hit exactly when that mod is in play.
##
## Hooks are plain typed methods on purpose -- no `call("name")`, no
## `has_method`, no signals -- so Ctrl+click and the debugger both follow them.

enum Category { SHOT_SPREAD, BALL_COLLISION, WALL, SPAWN_DIRECTION, SHAPE, ROTATION, DENSITY, GRID, LOSS }

## Display names, indexed by Category.
const CATEGORY_NAMES: Array[String] = [
	"Shot spread", "Ball collision", "Wall", "Spawn direction",
	"Shape", "Rotation", "Density", "Grid", "Loss",
]

var category: Category = Category.SHOT_SPREAD
var display_name: String = "None"
var description: String = ""
## False = listed in the Custom screen but greyed out (not built yet).
var available: bool = true
## Unlock id (see the Unlocks autoload) that must be earned before this mod
## can be picked. Empty = always unlocked.
var locked_by: StringName = &""
## False = the ? panel loops draw_preview full-size instead of running a live
## mini-board (for mods a 4x5 board can't show, like Lives or a grid size).
var live_preview: bool = true

static func category_name(c: Category) -> String:
	return CATEGORY_NAMES[c]

## Available, and unlocked if it needs to be.
func is_selectable() -> bool:
	return available and (locked_by == &"" or Unlocks.is_unlocked(locked_by))


# ----------------------------------------------------------------- preview

## Draw a looping sketch of this mod into `rect` on `canvas` at `t` seconds.
## t = 0 is the static tile icon; hover advances t. Use PreviewDraw so every
## icon shares one look. Default: the category's initial on a blank board.
func draw_preview(canvas: CanvasItem, rect: Rect2, _t: float) -> void:
	PreviewDraw.board(canvas, rect)
	PreviewDraw.text(canvas, rect.get_center(), category_name(category).left(1),
		int(rect.size.y * 0.4), PreviewDraw.FRAME)


# ------------------------------------------------------------- every mod

## Value tweaks, once per run, right after install.
func apply(_rules: GameRules) -> void:
	pass

## A HUD line for this mod ("LIVES 2"). Empty = nothing shown.
func status_text(_rules: GameRules) -> String:
	return ""

## The board exists (after the first layout, and again after a Debug Menu
## grid apply). Mods that put things on the field add nodes under
## `field.effects_root` here. Called for every installed mod.
func on_run_start(_rules: GameRules, _field: Playfield) -> void:
	pass

## A round just resolved: the field has shifted down and the next row is in.
## Called for every installed mod.
func on_round_end(_rules: GameRules, _field: Playfield) -> void:
	pass


# ----------------------------------------------------------------- DENSITY

func row_units(rules: GameRules, round_number: int) -> int:
	return rules.default_row_units(round_number)

func unit_value(rules: GameRules, round_number: int) -> int:
	return rules.default_unit_value(round_number)

func open_slots(rules: GameRules) -> int:
	return rules.default_open_slots()


# ---------------------------------------------------------- BALL_COLLISION

func shots_for_round(rules: GameRules, ball_count: int) -> int:
	return rules.default_shots_for_round(ball_count)

## True = every ball records its path (one point per physics frame) so the
## mod can play it back (Time Rewind). Off by default: normal runs pay nothing.
func wants_path_recording(_rules: GameRules) -> bool:
	return false

## Each frame while FIRING, with seconds since the round's first shot.
func on_firing_tick(_rules: GameRules, _game: Game, _seconds: float) -> void:
	pass

## Damage `ball` deals on this block contact.
func damage_for(rules: GameRules, _ball: Ball) -> int:
	return rules.ball_damage


# -------------------------------------------------------------------- WALL

## `ball` finished moving for this physics frame (after any bounces).
func on_ball_moved(_rules: GameRules, _ball: Ball) -> void:
	pass

## `ball` just touched a wall. Return true if the mod handled it -- the ball
## then skips its normal bounce for this contact.
func on_wall_hit(_rules: GameRules, _ball: Ball, _collision: KinematicCollision2D) -> bool:
	return false


# ---------------------------------------------------------- SHAPE, ROTATION

## A freshly placed block, after `Block.setup()`. The SHAPE slot runs first,
## then ROTATION.
func configure_block(_rules: GameRules, _block: Block) -> void:
	pass


# -------------------------------------------------------------------- LOSS

func death_row(rules: GameRules) -> int:
	return rules.default_death_row()

## `blocks` just landed on the death row this shift. Return true if the run
## continues -- the mod is then responsible for clearing them.
func on_death_row_reached(_rules: GameRules, _blocks: Array[Block]) -> bool:
	return false
