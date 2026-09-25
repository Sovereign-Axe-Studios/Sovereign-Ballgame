extends Node
## Cfg -- the single entry point for every shipped-default tunable (autoload).
##
## THE DEFINITIONS LIVE IN `scripts/config/*.gd`, one file per domain. This
## file is a thin index over them: namespaced preloads, then a flat re-export
## of every constant, alphabetical within each domain group. Splitting them is
## what keeps a rebalance -- and the rationale comment that goes with it --
## inside one small file.
##
## `GameRules` (`scripts/game_rules.gd`) is the mod seam -- see
## docs/ROADMAP.md -- and it preloads the SAME domain files directly rather
## than reading through this autoload. A Resource's @export defaults must
## resolve even when the editor instantiates one outside of a running game,
## before any autoload exists, so GameRules cannot depend on `Cfg` being in
## the scene tree. `Cfg` exists for every other script that wants a quick
## `Cfg.GRID_WIDTH` without pulling a `GameRules` instance through the tree.
##
## Both forms are correct: `Cfg.Board.GRID_WIDTH` says where a value is
## defined; `Cfg.GRID_WIDTH` is the flat form for a call site that does not
## care which domain it came from. Neither is "the real one" -- pick whichever
## reads better at the call site.
##
## These are shipped defaults and never change at runtime. Runtime overrides
## -- the Debug Menu's grid/fragment fields today, mods later -- write to the
## live `GameRules` instance (`Game.rules`), never to `Cfg`. Session flags
## live on the `Debug` autoload, not here.

# --- Domains ----------------------------------------------------------------
const Board := preload("res://scripts/config/board.gd")
const Spawning := preload("res://scripts/config/spawning.gd")
const Ball := preload("res://scripts/config/ball.gd")
const WallCorners := preload("res://scripts/config/wall_corners.gd")
const Shooter := preload("res://scripts/config/shooter.gd")
const Loss := preload("res://scripts/config/loss.gd")
const Juice := preload("res://scripts/config/juice.gd")

# --- Flat re-exports. Alphabetical within each domain. ----------------------

# Board
const FLOOR_Y := Board.FLOOR_Y
const GRID_HEIGHT := Board.GRID_HEIGHT
const GRID_TOP := Board.GRID_TOP
const GRID_WIDTH := Board.GRID_WIDTH
const SHOOTER_HEIGHT := Board.SHOOTER_HEIGHT
const SIDE_MARGIN := Board.SIDE_MARGIN
const SPAWN_ROW_INDEX := Board.SPAWN_ROW_INDEX

# Spawning
const MAX_OPEN_SLOTS := Spawning.MAX_OPEN_SLOTS
const MAX_UNITS_PER_CELL := Spawning.MAX_UNITS_PER_CELL
const MIN_OPEN_SLOTS := Spawning.MIN_OPEN_SLOTS
const PICKUP_CHANCE := Spawning.PICKUP_CHANCE
const UNITS_PER_COLUMN := Spawning.UNITS_PER_COLUMN

# Ball
const BALL_DAMAGE := Ball.BALL_DAMAGE
const BALL_FIRE_INTERVAL := Ball.BALL_FIRE_INTERVAL
const BALL_MAX_LIFETIME := Ball.BALL_MAX_LIFETIME
const BALL_MIN_VERTICAL := Ball.BALL_MIN_VERTICAL
const BALL_RADIUS := Ball.BALL_RADIUS
const BALL_SPEED := Ball.BALL_SPEED
const BALLS_RETURN_TO_LANDER := Ball.BALLS_RETURN_TO_LANDER

# WallCorners
const CORNER_JITTER_DEGREES := WallCorners.CORNER_JITTER_DEGREES
const CORNER_RADIUS := WallCorners.CORNER_RADIUS

# Shooter
const AIM_SPEED_DEGREES := Shooter.AIM_SPEED_DEGREES
const MAX_AIM_DEGREES := Shooter.MAX_AIM_DEGREES
const RANDOM_ROTATE_VALUE_DEG := Shooter.RANDOM_ROTATE_VALUE_DEG

# Loss
const DEATH_ROW_OVERRIDE := Loss.DEATH_ROW_OVERRIDE

# Juice
const FRAGMENT_COLS_MAX := Juice.FRAGMENT_COLS_MAX
const FRAGMENT_COLS_MIN := Juice.FRAGMENT_COLS_MIN
const FRAGMENT_ROWS_MAX := Juice.FRAGMENT_ROWS_MAX
const FRAGMENT_ROWS_MIN := Juice.FRAGMENT_ROWS_MIN

# --- Mods -------------------------------------------------------------------
# One line per mod file (scripts/mods/<category>/*.gd). `Cfg.Boss.UNITS`
# Ctrl+clicks through to the constant. MODS is the registry the mode screens
# read, in Category order. Deleting a mod file makes its line here fail to
# parse, and that error is the guard.
const Spread := preload("res://scripts/mods/shot_spread/spread.gd")
const Snowball := preload("res://scripts/mods/ball_collision/snowball.gd")
const WrapAround := preload("res://scripts/mods/wall/wrap_around.gd")
const Reinforcements := preload("res://scripts/mods/spawn_direction/reinforcements.gd")
const Circles := preload("res://scripts/mods/shape/circles.gd")
const Rotated := preload("res://scripts/mods/rotation/rotated.gd")
const Boss := preload("res://scripts/mods/density/boss.gd")
const ModifiedGrid := preload("res://scripts/mods/grid/modified_grid.gd")
const Lives := preload("res://scripts/mods/loss/lives.gd")

const MODS: Array[GDScript] = [
	Spread, Snowball, WrapAround, Reinforcements, Circles, Rotated,
	Boss, ModifiedGrid, Lives,
]
