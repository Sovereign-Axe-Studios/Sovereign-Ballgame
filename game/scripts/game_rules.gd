class_name GameRules
extends Resource
## Every tunable number for a run lives here, and nowhere else.
##
## This is the seam the mod system plugs into later. A mod is ultimately either
## (a) a tweak to these values, or (b) a subclass that overrides one of the
## virtual hooks at the bottom. Gameplay scripts never hardcode a magic number;
## they read it from the GameRules instance handed to them by Game.
##
## See docs/ROADMAP.md -> "Modularity basics" for where this is going.

# --------------------------------------------------------------------- layout
@export_group("Layout")
## Columns in the playfield.
@export var grid_width: int = 7
## Rows total, including spawn row (0) and death row (grid_height - 1).
@export var grid_height: int = 7
## Gap between screen edge and the inner face of the side walls.
@export var side_margin: float = 40.0
## Y of the ceiling, i.e. the top of row 0.
@export var grid_top: float = 280.0
## Y of the floor line. A ball crossing this is out for the round.
@export var floor_y: float = 1820.0
## How far above the floor the shooter sits.
@export var shooter_height: float = 70.0

# --------------------------------------------------------------- row spawning
@export_group("Row spawning")
## A row is handed `units_per_column * grid_width` units, and every unit is
## worth the round number. So a round-3 row on a width-7 board spends 7 units
## of 3, and every block it makes is a multiple of 3: 3, 6, 9, 12...
## Density mods (Dense, Solid, Boss, Mafia, Pawn wall) move this number.
@export var units_per_column: float = 1.0
## How many columns a new row leaves empty, picked per row from this range.
## At least one, always: a sealed row is a dead round.
@export var min_open_slots: int = 1
@export var max_open_slots: int = 3
## Most units that may stack on a single cell. 0 = no cap. Raised automatically
## if the row's units could not otherwise fit in the cells available.
@export var max_units_per_cell: int = 4
## Chance a new row also drops a +1 ball pickup, if an empty column exists.
@export_range(0.0, 1.0) var pickup_chance: float = 1.0

# ----------------------------------------------------------------------- ball
@export_group("Ball")
@export var ball_radius: float = 17.0
@export var ball_speed: float = 1750.0
## Damage one ball does per block contact.
@export var ball_damage: int = 1
## Seconds between each ball leaving the shooter.
## NOTE: Theo's spec says "one every second". That reads as a placeholder --
## at round 40 it would be 40 seconds of watching balls queue up. 0.09 is in
## the same neighbourhood as the original game. Turn it up if you disagree.
@export var ball_fire_interval: float = 0.09
## Hard stop so a ball trapped in a horizontal groove cannot stall the round.
@export var ball_max_lifetime: float = 18.0
## After a bounce, force at least this much vertical travel (fraction of speed).
## Without it, balls settle into flat left-right loops and never come down.
@export_range(0.0, 0.5) var ball_min_vertical: float = 0.18
## Once the round's first ball lands, the shooter slides to where it landed and
## the rest return there. This is how the original game feels. Off = fixed shooter.
@export var balls_return_to_lander: bool = true

# --------------------------------------------------------------- wall corners
@export_group("Wall corners")
## Hitting a wall within this many pixels of a corner scatters the bounce a
## little, so balls do not settle into a perfect repeating path.
@export var corner_radius: float = 90.0
## Maximum scatter applied there, in degrees.
@export var corner_jitter_degrees: float = 12.0

# -------------------------------------------------------------------- shooter
@export_group("Shooter")
## Aim is clamped to +/- this many degrees off straight up.
@export var max_aim_degrees: float = 78.0
## Degrees per second while an aim key is held.
@export var aim_speed_degrees: float = 90.0

# ----------------------------------------------------------------------- loss
@export_group("Loss")
## Which row kills you. -1 means "the bottom row".
@export var death_row_override: int = -1

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
