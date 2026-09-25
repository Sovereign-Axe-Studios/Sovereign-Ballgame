class_name ModLivePreview
extends SubViewportContainer
## The ? panel's live mini-game: a small board in its own SubViewport running
## the real GridManager / Ball / Block code with one mod installed, firing on
## a scripted aim so the effect reliably shows. No HUD, pickups, or loss --
## rows never shift down, and the board refills when it's cleared.

const BallScene := preload("res://scenes/ball.tscn")

## Preview board shape. Small on purpose: the point is the mod, not a game.
const COLS := 4
const ROWS := 5
## Rows 1..FILLED_ROWS get blocks on each refill.
const FILLED_ROWS := 3
const MARGIN := 20.0
## Seconds between volleys, and between balls in one volley.
const VOLLEY_INTERVAL := 0.8
const SHOT_INTERVAL := 0.12
## Balls per volley before shots_for_round (so Snowball fires fewer).
const VOLLEY_BALLS := 3
## Aim angles cycled volley to volley, degrees off straight up. Mixed sides
## and steepness so wall and corner mods both get exercised.
const AIM_SCRIPT: Array[float] = [-38.0, 24.0, -12.0, 44.0, -28.0, 8.0]
## Slow-motion factor on ball speed. At full speed a ball crosses this small
## board in under half a second, too fast to read what the mod did.
const SPEED_SCALE := 0.5

var _rules: GameRules
var _grid: GridManager
var _balls_root: Node2D
var _shooter: Shooter
var _origin := Vector2.ZERO
var _volley_cd: float = 0.3
var _shot_cd: float = 0.0
var _to_fire: int = 0
var _aim_index: int = 0
var _refills: int = 0
var _field := Playfield.new()

var _mod: GameMod
var _view_size := Vector2.ZERO

func _init(mod: GameMod, view_size: Vector2) -> void:
	_mod = mod
	_view_size = view_size
	custom_minimum_size = view_size
	stretch = true

## Built here, not in _init: Blocks touch @onready nodes in setup(), which
## only exist once this is in the tree.
func _ready() -> void:
	var view_size := _view_size
	var sub := SubViewport.new()
	sub.size = Vector2i(view_size)
	sub.world_2d = World2D.new()   # its own physics space, never the menu's
	sub.transparent_bg = false
	add_child(sub)

	var board := Node2D.new()
	sub.add_child(board)
	var bg := ColorRect.new()
	bg.color = Skins.background().color
	bg.size = view_size
	board.add_child(bg)

	_rules = GameRules.new()
	var mods: Array[GameMod] = [_mod]
	_rules.install(mods)
	_layout(view_size)

	var walls := Node2D.new()
	board.add_child(walls)
	Playfield.build_walls(walls, _rules, view_size.x)

	_grid = GridManager.new()
	board.add_child(_grid)
	var cell := (_rules.play_right - _rules.play_left) / float(COLS)
	_grid.configure(_rules, cell, Vector2(_rules.play_left, _rules.grid_top))

	_balls_root = Node2D.new()
	board.add_child(_balls_root)
	_origin = Vector2(view_size.x * 0.5, _rules.floor_y - _rules.shooter_height)

	_shooter = Shooter.new()
	board.add_child(_shooter)
	_shooter.setup(_rules)
	_shooter.position = _origin
	_shooter.set_aim(AIM_SCRIPT[0])

	var effects := Node2D.new()
	board.add_child(effects)
	_field.rules = _rules
	_field.grid = _grid
	_field.effects_root = effects
	_refill()
	_rules.on_run_start(_field)

## Shrink the full-size rules to this board, scaling ball size and speed by
## the cell-size ratio so it plays like the real thing, just smaller.
func _layout(view_size: Vector2) -> void:
	var full_cell := (float(ProjectSettings.get_setting("display/window/size/viewport_width"))
		- 2.0 * _rules.side_margin) / float(_rules.grid_width)
	_rules.grid_width = COLS
	_rules.grid_height = ROWS
	_rules.death_row_override = -1
	_rules.pickup_chance = 0.0
	_rules.side_margin = MARGIN
	_rules.play_left = MARGIN
	_rules.play_right = view_size.x - MARGIN
	_rules.grid_top = MARGIN
	var cell := (_rules.play_right - _rules.play_left) / float(COLS)
	var k := cell / full_cell
	_rules.ball_radius *= k
	_rules.ball_speed *= k * SPEED_SCALE
	_rules.shooter_height = cell * 0.4
	_rules.floor_y = view_size.y - MARGIN
	_rules.corner_radius *= k

func _process(delta: float) -> void:
	if _grid.block_count() == 0 and _balls_root.get_child_count() == 0:
		_refill()

	_volley_cd -= delta
	if _volley_cd <= 0.0 and _to_fire <= 0 and _balls_root.get_child_count() == 0:
		_volley_cd = VOLLEY_INTERVAL
		_to_fire = _rules.shots_for_round(VOLLEY_BALLS)
		_shot_cd = 0.0

	if _to_fire > 0:
		_shot_cd -= delta
		if _shot_cd <= 0.0:
			_shot_cd = SHOT_INTERVAL
			_to_fire -= 1
			_fire()
			if _to_fire == 0:
				_aim_index = (_aim_index + 1) % AIM_SCRIPT.size()
				_shooter.set_aim(AIM_SCRIPT[_aim_index])

func _fire() -> void:
	var ball: Ball = BallScene.instantiate()
	_balls_root.add_child(ball)
	var aim := Vector2.UP.rotated(deg_to_rad(AIM_SCRIPT[_aim_index]))
	ball.launch(_rules, _origin, _rules.spread_direction(aim))
	ball.finished.connect(func(b: Ball) -> void: b.queue_free())

func _refill() -> void:
	_grid.clear_all()
	_refills += 1
	for row in range(1, FILLED_ROWS + 1):
		_rules.spawn_row_index = row
		# Later refills use higher rounds so values (and colours) vary.
		_grid.spawn_row(_refills + FILLED_ROWS - row + 1)
	if _refills > 1:
		# A refill stands in for a round ending (e.g. Wormholes relocate).
		_rules.on_round_end(_field)
