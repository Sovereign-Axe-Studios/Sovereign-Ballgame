class_name GameRules
extends Resource
## Every tunable number for a run lives here, and nowhere else.
##
## This is the seam the mod system plugs into later. A mod is ultimately either
## (a) a tweak to these values, or (b) a subclass that overrides one of the
## virtual hooks at the bottom. Gameplay scripts never hardcode a magic number;
## they read it from the GameRules instance handed to them by Game.
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

func death_row() -> int:
	return grid_height - 1 if death_row_override < 0 else death_row_override


# ------------------------------------------------------------- virtual hooks
# Mods override these. Kept tiny and pure on purpose.

## How many units a row spawned for `round_number` gets to hand out.
func row_units(_round_number: int) -> int:
	return maxi(1, int(round(units_per_column * float(grid_width))))

## What one unit is worth. Every block in the row is a multiple of this.
func unit_value(round_number: int) -> int:
	return maxi(1, round_number)

## How many columns this row leaves empty.
func open_slots() -> int:
	var lo := clampi(mini(min_open_slots, max_open_slots), 1, grid_width - 1)
	var hi := clampi(maxi(min_open_slots, max_open_slots), lo, grid_width - 1)
	return randi_range(lo, hi)

## How many balls the player fires on a given round. Ball-count mods (Missiles,
## Snowball, Sniper...) live here.
func shots_for_round(ball_count: int) -> int:
	return maxi(1, ball_count)
