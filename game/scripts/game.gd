class_name Game
extends Node2D
## Round loop, playfield construction, and scoring.
##
## A round is: aim -> fire every ball -> wait for them all to land -> bank
## pickups -> shift the field down -> lose, or spawn the next row and aim again.

enum State { AIMING, FIRING, RESOLVING, GAME_OVER }

const BallScene := preload("res://scenes/ball.tscn")

## Drop a .tres here to run the game under different rules. Empty = defaults.
@export var rules: GameRules

@onready var grid: GridManager = $Grid
@onready var shooter: Shooter = $Shooter
@onready var balls_root: Node2D = $Balls
@onready var walls_root: Node2D = $Walls
@onready var hud: HUD = $HUD

var state: State = State.AIMING
var round_number: int = 1
var ball_count: int = 1
var pending_balls: int = 0
var round_damage: int = 0
var total_damage: int = 0

var _to_fire: int = 0
var _fire_cd: float = 0.0
var _live_balls: int = 0
var _landing_x: float = 0.0
var _has_landing: bool = false
var _fire_origin := Vector2.ZERO
var _play_left: float = 0.0
var _play_right: float = 0.0
var _dragging: bool = false


func _ready() -> void:
	randomize()
	if rules == null:
		rules = GameRules.new()

	var vp := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	_play_left = rules.side_margin
	_play_right = vp.x - rules.side_margin

	# Square cells. Width usually decides, but clamp so a taller grid (a mod
	# changing grid_height) still leaves the shooter room to work.
	var by_width := (_play_right - _play_left) / float(rules.grid_width)
	var free_height := (rules.floor_y - rules.shooter_height - 140.0) - rules.grid_top
	var by_height := free_height / float(rules.grid_height)
	var cell := minf(by_width, by_height)

	var grid_w := cell * float(rules.grid_width)
	var org := Vector2((vp.x - grid_w) * 0.5, rules.grid_top)
	grid.configure(rules, cell, org)
	grid.pickup_collected.connect(_on_pickup_collected)

	_build_walls(vp)

	shooter.setup(rules)
	shooter.position = Vector2(vp.x * 0.5, rules.floor_y - rules.shooter_height)

	grid.spawn_row(round_number)
	_refresh_hud()
	queue_redraw()


## Solid rectangles rather than WorldBoundaryShape2D: a fast ball that clips a
## boundary line can end up on the wrong side of it, a thick box it cannot.
func _build_walls(vp: Vector2) -> void:
	for child in walls_root.get_children():
		child.queue_free()

	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("wall")
	walls_root.add_child(body)

	var span := rules.floor_y - rules.grid_top
	var mid_y := (rules.grid_top + rules.floor_y) * 0.5
	var thickness := 400.0

	_add_wall(body, Vector2(thickness, span + thickness * 2.0), Vector2(_play_left - thickness * 0.5, mid_y))
	_add_wall(body, Vector2(thickness, span + thickness * 2.0), Vector2(_play_right + thickness * 0.5, mid_y))
	_add_wall(body, Vector2(vp.x + thickness * 2.0, thickness), Vector2(vp.x * 0.5, rules.grid_top - thickness * 0.5))

func _add_wall(body: StaticBody2D, size: Vector2, pos: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = pos
	body.add_child(shape)


# --------------------------------------------------------------------- input

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return

	match state:
		State.AIMING:
			var axis := Input.get_axis("aim_left", "aim_right")
			if not is_zero_approx(axis):
				shooter.nudge(axis * rules.aim_speed_degrees * delta)
			if Input.is_action_just_pressed("fire"):
				_begin_firing()
			elif Input.is_action_just_pressed("debug_shift_down"):
				_debug_advance()
			elif Input.is_action_just_pressed("debug_shift_up"):
				grid.shift_up()
		State.FIRING:
			_tick_firing(delta)

## Press-and-drag aiming. The full drag/line treatment is a later build step;
## this is enough to make the game testable with a mouse or a thumb.
func _unhandled_input(event: InputEvent) -> void:
	if state != State.AIMING:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_dragging = true
			shooter.aim_at(get_global_mouse_position())
		elif _dragging:
			_dragging = false
			_begin_firing()
	elif event is InputEventMouseMotion and _dragging:
		shooter.aim_at(get_global_mouse_position())


# ---------------------------------------------------------------- round loop

func _begin_firing() -> void:
	state = State.FIRING
	_to_fire = rules.shots_for_round(ball_count)
	_fire_cd = 0.0
	_live_balls = 0
	_has_landing = false
	round_damage = 0
	_fire_origin = shooter.global_position
	shooter.active = false
	shooter.queue_redraw()
	_refresh_hud()

func _tick_firing(delta: float) -> void:
	if _to_fire <= 0:
		return
	var interval := maxf(0.001, rules.ball_fire_interval)
	_fire_cd -= delta
	while _fire_cd <= 0.0 and _to_fire > 0:
		_spawn_ball()
		_to_fire -= 1
		_fire_cd += interval

func _spawn_ball() -> void:
	var ball: Ball = BallScene.instantiate()
	balls_root.add_child(ball)
	ball.launch(rules, _fire_origin, shooter.aim_direction())
	ball.finished.connect(_on_ball_finished)
	ball.block_damaged.connect(_on_block_damaged)
	_live_balls += 1

func _on_ball_finished(ball: Ball) -> void:
	_live_balls -= 1
	if not _has_landing:
		_has_landing = true
		_landing_x = clampf(
			ball.global_position.x,
			_play_left + rules.ball_radius,
			_play_right - rules.ball_radius
		)
	ball.queue_free()
	if _to_fire <= 0 and _live_balls <= 0:
		_end_round()

func _on_block_damaged(_block: Block, damage: int) -> void:
	round_damage += damage
	total_damage += damage
	_refresh_hud()

func _on_pickup_collected(_pickup: BallPickup) -> void:
	pending_balls += 1
	_refresh_hud()

func _end_round() -> void:
	state = State.RESOLVING

	# The shooter follows the first ball home, the way the original does.
	if rules.balls_return_to_lander and _has_landing:
		shooter.position.x = _landing_x

	ball_count += pending_balls
	pending_balls = 0

	if grid.advance():
		_game_over()
		return

	round_number += 1
	grid.spawn_row(round_number)
	shooter.active = true
	shooter.queue_redraw()
	state = State.AIMING
	_refresh_hud()

func _debug_advance() -> void:
	if grid.advance():
		_game_over()
		return
	round_number += 1
	grid.spawn_row(round_number)
	_refresh_hud()

func _game_over() -> void:
	state = State.GAME_OVER
	shooter.active = false
	shooter.queue_redraw()
	print("DEBUG: lose game -- a block reached row %d on round %d (total damage %d)"
		% [rules.death_row(), round_number, total_damage])
	hud.show_game_over(round_number, total_damage)

func _refresh_hud() -> void:
	hud.refresh(round_number, ball_count, pending_balls, round_damage, total_damage)


# --------------------------------------------------------------- playfield fx

func _draw() -> void:
	if rules == null:
		return
	var vp_w := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var vp_h := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	draw_rect(Rect2(Vector2.ZERO, Vector2(vp_w, vp_h)), Palette.BACKGROUND, true)

	# Walls and ceiling.
	var t := 8.0
	var span := rules.floor_y - rules.grid_top + t
	var top := rules.grid_top - t
	draw_rect(Rect2(Vector2(_play_left - t, top), Vector2(t, span)), Palette.WALL, true)
	draw_rect(Rect2(Vector2(_play_right, top), Vector2(t, span)), Palette.WALL, true)
	var lintel := Vector2(_play_right - _play_left + t * 2.0, t)
	draw_rect(Rect2(Vector2(_play_left - t, top), lintel), Palette.WALL, true)

	# The floor is a kill line, not a surface, so it is drawn dashed.
	var x := _play_left
	while x < _play_right:
		draw_line(Vector2(x, rules.floor_y), Vector2(minf(x + 22.0, _play_right), rules.floor_y), Palette.FLOOR_LINE, 4.0)
		x += 38.0
