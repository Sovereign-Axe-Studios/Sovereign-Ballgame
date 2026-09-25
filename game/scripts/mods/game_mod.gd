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

static func category_name(c: Category) -> String:
	return CATEGORY_NAMES[c]


# ------------------------------------------------------------- every mod

## Value tweaks, once per run, right after install.
func apply(_rules: GameRules) -> void:
	pass

## A HUD line for this mod ("LIVES 2"). Empty = nothing shown.
func status_text(_rules: GameRules) -> String:
	return ""


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

## Damage `ball` deals on this block contact.
func damage_for(rules: GameRules, _ball: Ball) -> int:
	return rules.ball_damage


# -------------------------------------------------------------------- WALL

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
