class_name GameRules
extends Resource
## Every tunable number for a run lives here, and nowhere else.
##
## This is the seam the mod system plugs into. `install()` puts one `GameMod`
## per category into a slot; a mod either tweaks these values (`apply`) or
## answers one of the hooks at the bottom, each of which is a direct call into
## the slot that owns it (see `scripts/mods/game_mod.gd`). Gameplay scripts
## never hardcode a magic number; they read it from the GameRules instance
## handed to them by Game.
##
## The values themselves -- and the rationale behind each one -- live in
## `scripts/config/*.gd`, one small file per domain, indexed by `scripts/cfg.gd`
## (the `Cfg` autoload). This resource preloads those SAME files directly for
## its @export defaults rather than reading through `Cfg`: a Resource's exports
## must resolve even when the editor instantiates one outside of a running
## game, before any autoload exists. `Cfg.GRID_WIDTH` and this script's
## `grid_width` default are therefore always the same number, just reached two
## different ways -- see `scripts/cfg.gd` for the full split rationale.
##
## See docs/ROADMAP.md -> "Modularity basics" for where this is going.

const _Board := preload("res://scripts/config/board.gd")
const _Spawning := preload("res://scripts/config/spawning.gd")
const _Ball := preload("res://scripts/config/ball.gd")
const _WallCorners := preload("res://scripts/config/wall_corners.gd")
const _Shooter := preload("res://scripts/config/shooter.gd")
const _Loss := preload("res://scripts/config/loss.gd")
const _Juice := preload("res://scripts/config/juice.gd")

# --------------------------------------------------------------------- layout
@export_group("Layout")
## Columns in the playfield.
@export var grid_width: int = _Board.GRID_WIDTH
## Rows total, including spawn row (0) and death row (grid_height - 1).
@export var grid_height: int = _Board.GRID_HEIGHT
## Gap between screen edge and the inner face of the side walls.
@export var side_margin: float = _Board.SIDE_MARGIN
## Y of the ceiling, i.e. the top of row 0.
@export var grid_top: float = _Board.GRID_TOP
## Y of the floor line. A ball crossing this is out for the round.
@export var floor_y: float = _Board.FLOOR_Y
## How far above the floor the shooter sits.
@export var shooter_height: float = _Board.SHOOTER_HEIGHT
## Which row `GridManager.spawn_row` targets. Debug-menu adjustable; see
## `scripts/config/board.gd` for why 0 is the sane default.
@export var spawn_row_index: int = _Board.SPAWN_ROW_INDEX

# --------------------------------------------------------------- row spawning
@export_group("Row spawning")
## A row is handed `units_per_column * grid_width` units, and every unit is
## worth the round number. See `scripts/config/spawning.gd` for the full
## rationale. Density mods (Dense, Solid, Boss, Mafia, Pawn wall) move this.
@export var units_per_column: float = _Spawning.UNITS_PER_COLUMN
## How many columns a new row leaves empty, picked per row from this range.
## At least one, always: a sealed row is a dead round.
@export var min_open_slots: int = _Spawning.MIN_OPEN_SLOTS
@export var max_open_slots: int = _Spawning.MAX_OPEN_SLOTS
## Most units that may stack on a single cell. 0 = no cap. Raised automatically
## if the row's units could not otherwise fit in the cells available.
@export var max_units_per_cell: int = _Spawning.MAX_UNITS_PER_CELL
## Chance a new row also drops a +1 ball pickup, if an empty column exists.
@export_range(0.0, 1.0) var pickup_chance: float = _Spawning.PICKUP_CHANCE

# ----------------------------------------------------------------------- ball
@export_group("Ball")
@export var ball_radius: float = _Ball.BALL_RADIUS
@export var ball_speed: float = _Ball.BALL_SPEED
## Damage one ball does per block contact.
@export var ball_damage: int = _Ball.BALL_DAMAGE
## Seconds between each ball leaving the shooter. See `scripts/config/ball.gd`
## for why this is 0.09 rather than Theo's spec'd 1.0.
@export var ball_fire_interval: float = _Ball.BALL_FIRE_INTERVAL
## Hard stop so a ball trapped in a horizontal groove cannot stall the round.
@export var ball_max_lifetime: float = _Ball.BALL_MAX_LIFETIME
## After a bounce, force at least this much vertical travel (fraction of speed).
## Without it, balls settle into flat left-right loops and never come down.
@export_range(0.0, 0.5) var ball_min_vertical: float = _Ball.BALL_MIN_VERTICAL
## Once the round's first ball lands, the shooter slides to where it landed and
## the rest return there. This is how the original game feels. Off = fixed shooter.
@export var balls_return_to_lander: bool = _Ball.BALLS_RETURN_TO_LANDER

# --------------------------------------------------------------- wall corners
@export_group("Wall corners")
## Hitting a wall within this many pixels of a corner scatters the bounce a
## little, so balls do not settle into a perfect repeating path.
@export var corner_radius: float = _WallCorners.CORNER_RADIUS
## Maximum scatter applied there, in degrees.
@export var corner_jitter_degrees: float = _WallCorners.CORNER_JITTER_DEGREES

# -------------------------------------------------------------------- shooter
@export_group("Shooter")
## Aim is clamped to +/- this many degrees off straight up.
@export var max_aim_degrees: float = _Shooter.MAX_AIM_DEGREES
## Degrees per second while an aim key is held.
@export var aim_speed_degrees: float = _Shooter.AIM_SPEED_DEGREES
## Each ball's launch direction is rotated by a random angle in +/- this many
## degrees. 0 is perfect accuracy.
@export var random_rotate_value_deg: float = _Shooter.RANDOM_ROTATE_VALUE_DEG

# ----------------------------------------------------------------------- loss
@export_group("Loss")
## Which row kills you. -1 means "the bottom row".
@export var death_row_override: int = _Loss.DEATH_ROW_OVERRIDE

# ---------------------------------------------------------------------- juice
@export_group("Juice")
## How many columns/rows a destroyed block cracks into. Each is a random pick
## in [MIN, MAX] per block; MIN == MAX for a constant. Debug-menu adjustable.
@export var fragment_cols_min: int = _Juice.FRAGMENT_COLS_MIN
@export var fragment_cols_max: int = _Juice.FRAGMENT_COLS_MAX
@export var fragment_rows_min: int = _Juice.FRAGMENT_ROWS_MIN
@export var fragment_rows_max: int = _Juice.FRAGMENT_ROWS_MAX

# ------------------------------------------------------------ runtime layout
# Not tunables: set by whoever lays the board out (Game._layout_playfield,
# ModLivePreview), so wall-aware code (corner jitter, Wrap Around) works on
# any board size instead of assuming the 1080-wide screen.

## X of the inner face of the left / right side wall.
var play_left: float = 0.0
var play_right: float = 0.0

# ---------------------------------------------------------------- mod slots

## Category -> installed GameMod. A category with no entry answers with
## `_stock`, a plain GameMod whose hooks are the default_* functions below.
var _slots: Dictionary = {}
var _stock := GameMod.new()

## Put each mod in its category's slot, then let each `apply()` its value
## tweaks. One mod per category: a second one replaces the first.
func install(mods: Array[GameMod]) -> void:
	for mod in mods:
		if not mod.is_selectable():
			push_warning("GameRules.install: skipping unavailable or locked mod '%s'" % mod.display_name)
			continue
		if _slots.has(mod.category):
			push_warning("GameRules.install: '%s' replaces '%s' in %s" % [
				mod.display_name, (_slots[mod.category] as GameMod).display_name,
				GameMod.category_name(mod.category)])
		_slots[mod.category] = mod
	for mod in active_mods():
		mod.apply(self)

## Installed mods, in Category order.
func active_mods() -> Array[GameMod]:
	var out: Array[GameMod] = []
	for c in GameMod.Category.values():
		if _slots.has(c):
			out.append(_slots[c])
	return out

func _slot(c: GameMod.Category) -> GameMod:
	return _slots.get(c, _stock)


# ---------------------------------------------------------------------- hooks
# Every hook is one direct call into the slot that owns it. The stock answers
# live in the default_* functions further down.

## How many units a row spawned for `round_number` gets to hand out.
func row_units(round_number: int) -> int:
	return _slot(GameMod.Category.DENSITY).row_units(self, round_number)

## What one unit is worth. Every block in the row is a multiple of this.
func unit_value(round_number: int) -> int:
	return _slot(GameMod.Category.DENSITY).unit_value(self, round_number)

## How many columns this row leaves empty.
func open_slots() -> int:
	return _slot(GameMod.Category.DENSITY).open_slots(self)

## How many balls the player fires on a given round.
func shots_for_round(ball_count: int) -> int:
	return _slot(GameMod.Category.BALL_COLLISION).shots_for_round(self, ball_count)

func ball_draw_scale(ball: Ball) -> float:
	return _slot(GameMod.Category.BALL_COLLISION).ball_draw_scale(self, ball)

func draw_ball_overlay(ball: Ball, radius: float) -> void:
	_slot(GameMod.Category.BALL_COLLISION).draw_ball_overlay(self, ball, radius)

func wants_path_recording() -> bool:
	return _slot(GameMod.Category.BALL_COLLISION).wants_path_recording(self)

func on_firing_tick(game: Game, seconds: float) -> void:
	_slot(GameMod.Category.BALL_COLLISION).on_firing_tick(self, game, seconds)

## Damage `ball` deals on a block contact.
func damage_for(ball: Ball) -> int:
	return _slot(GameMod.Category.BALL_COLLISION).damage_for(self, ball)

func shot_direction(aim: Vector2, shot_index: int) -> Vector2:
	return _slot(GameMod.Category.SHOT_SPREAD).shot_direction(self, aim, shot_index)

## End-of-round field step; true = lost.
func advance_field(grid: GridManager, round_number: int) -> bool:
	return _slot(GameMod.Category.SPAWN_DIRECTION).advance_field(self, grid, round_number)

func choose_columns(width: int, count: int, round_number: int) -> Array[int]:
	return _slot(GameMod.Category.DENSITY).choose_columns(self, width, count, round_number)

func on_block_hit(ball: Ball, block: Block) -> void:
	_slot(GameMod.Category.BALL_COLLISION).on_block_hit(self, ball, block)

func configure_ball(ball: Ball) -> void:
	_slot(GameMod.Category.WALL).configure_ball(self, ball)

## After each Ball physics frame's movement.
func on_ball_moved(ball: Ball) -> void:
	_slot(GameMod.Category.WALL).on_ball_moved(self, ball)

## Every installed mod, in Category order: the board is laid out.
func on_run_start(field: Playfield) -> void:
	for mod in active_mods():
		mod.on_run_start(self, field)

## Every installed mod, in Category order: a round resolved.
func on_round_end(field: Playfield) -> void:
	for mod in active_mods():
		mod.on_round_end(self, field)

## True = the WALL mod handled this contact; the ball skips its bounce.
func on_wall_hit(ball: Ball, collision: KinematicCollision2D) -> bool:
	return _slot(GameMod.Category.WALL).on_wall_hit(self, ball, collision)

## Shape first, then rotation, so rotation sees the final body.
func configure_block(block: Block) -> void:
	_slot(GameMod.Category.SHAPE).configure_block(self, block)
	_slot(GameMod.Category.ROTATION).configure_block(self, block)

func death_row() -> int:
	return _slot(GameMod.Category.LOSS).death_row(self)

## True = the run continues (the LOSS mod cleared `blocks`).
func on_death_row_reached(blocks: Array[Block]) -> bool:
	return _slot(GameMod.Category.LOSS).on_death_row_reached(self, blocks)

## `aim` wobbled by up to +/- random_rotate_value_deg (Spread). Shared by
## Game and the ? panel's live preview so both fire the same way.
func spread_direction(aim: Vector2) -> Vector2:
	if random_rotate_value_deg == 0.0:
		return aim
	var spread := deg_to_rad(random_rotate_value_deg)
	return aim.rotated(randf_range(-spread, spread))

## Every installed mod's non-empty HUD line.
func status_lines() -> Array[String]:
	var out: Array[String] = []
	for mod in active_mods():
		var line := mod.status_text(self)
		if line != "":
			out.append(line)
	return out


# ----------------------------------------------------------- stock behaviour
# What an empty slot does. Mods call these too, to fall back or build on them.

func default_death_row() -> int:
	return grid_height - 1 if death_row_override < 0 else death_row_override

func default_row_units(_round_number: int) -> int:
	return maxi(1, int(round(units_per_column * float(grid_width))))

func default_unit_value(round_number: int) -> int:
	return maxi(1, round_number)

func default_open_slots() -> int:
	var lo := clampi(mini(min_open_slots, max_open_slots), 1, grid_width - 1)
	var hi := clampi(maxi(min_open_slots, max_open_slots), lo, grid_width - 1)
	return randi_range(lo, hi)

func default_shots_for_round(ball_count: int) -> int:
	return maxi(1, ball_count)
