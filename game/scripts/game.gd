class_name Game
extends Node2D
## Round loop, playfield construction, and scoring.
##
## A round is: aim -> fire every ball -> wait for them all to land -> bank
## pickups -> shift the field down -> lose, or spawn the next row and aim again.

enum State { AIMING, FIRING, RESOLVING, GAME_OVER }

const BallScene := preload("res://scenes/ball.tscn")
const DEBUG_MOVE_SPEED := 700.0 ## px/sec for the debug left/right launch-position nudge.
const SHOOTER_SLIDE_DURATION := 0.28
const BALL_RETURN_MIN_DURATION := 0.32
const BALL_RETURN_MAX_DURATION := 0.5

## Drop a .tres here to run the game under different rules. Empty = defaults.
@export var rules: GameRules

@onready var grid: GridManager = $Grid
@onready var shooter: Shooter = $Shooter
@onready var balls_root: Node2D = $Balls
@onready var walls_root: Node2D = $Walls
@onready var effects_root: Node2D = $Effects
@onready var hud: HUD = $HUD
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var debug_overlay: DebugOverlay = $DebugOverlay

var state: State = State.AIMING
var round_number: int = 1
var ball_count: int = 1
var pending_balls: int = 0
var round_damage: int = 0
var total_damage: int = 0

## Debug-only bookkeeping. See scripts/debug_state.gd and the debug section
## below for what reads/writes these.
var debug_row_credit: int = 0
var expected_ball_count: int = 1
var expected_round_number: int = 1

var _to_fire: int = 0
var _fire_cd: float = 0.0
var _live_balls: int = 0
var _landing_x: float = 0.0
var _has_landing: bool = false
var _fire_origin := Vector2.ZERO
var _play_left: float = 0.0
var _play_right: float = 0.0
var _dragging: bool = false
var _debug_touches: Dictionary = {} ## touch index -> screen position, for the two-finger-tap destroy gesture.
var _landed_balls: Array[Ball] = [] ## finished but not yet freed -- gathered to the new launch spot in _end_round.


func _ready() -> void:
	randomize()
	if rules == null:
		rules = GameRules.new()

	grid.pickup_collected.connect(_on_pickup_collected)
	grid.block_destroyed.connect(_on_block_destroyed)
	pause_menu.grid_apply_requested.connect(_on_debug_grid_apply)
	Skins.changed.connect(queue_redraw)

	_layout_playfield()
	_prime_board()
	_refresh_hud()
	queue_redraw()

## Sizes cells, rebuilds the walls, and repositions the shooter from `rules`.
## Split out of `_ready` so the debug menu's grid-size apply can re-run it
## without duplicating the math.
func _layout_playfield() -> void:
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

	_build_walls(vp)

	shooter.setup(rules)
	shooter.position = Vector2(vp.x * 0.5, rules.floor_y - rules.shooter_height)
	queue_redraw()

## Spawn round 1's row into row 0, then shift it into row 1 immediately -- the
## same spawn-then-shift sequence _end_round uses -- so row 0 reads as clear
## from the very first frame, not just after the first round ends. Re-run
## after a debug grid-size apply too, since that clears the whole board.
func _prime_board() -> void:
	grid.spawn_row(round_number)
	grid.advance()


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
	if Input.is_action_just_pressed("pause"):
		pause_menu.open()
		return

	if Debug.enabled:
		_tick_debug_input(delta)

	match state:
		State.AIMING:
			var axis := Input.get_axis("aim_left", "aim_right")
			if not is_zero_approx(axis):
				shooter.nudge(axis * rules.aim_speed_degrees * delta)
			if Input.is_action_just_pressed("fire"):
				_begin_firing()
		State.FIRING:
			_tick_firing(delta)

## Press-and-drag aiming. The full drag/line treatment is a later build step;
## this is enough to make the game testable with a mouse or a thumb.
func _unhandled_input(event: InputEvent) -> void:
	if Debug.enabled and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var point := get_global_mouse_position()
			if grid.block_at(point) != null:
				var destroy := Input.is_action_pressed("debug_shift_hold")
				debug_damage_at(point, destroy)
				return

	if Debug.enabled and event is InputEventScreenTouch:
		_handle_debug_touch(event as InputEventScreenTouch)

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
	# Not freed here -- kept around and gathered to the new launch spot once
	# _end_round knows where that is. See return_to() on Ball.
	_landed_balls.append(ball)
	if _to_fire <= 0 and _live_balls <= 0:
		_end_round()

func _on_block_damaged(block: Block, damage: int) -> void:
	round_damage += damage
	total_damage += damage
	if is_instance_valid(block) and block.value > 0:
		_spawn_hit_chunks(block.global_position, block.get_color(), block.get_size())
	_refresh_hud()

func _on_block_destroyed(block: Block) -> void:
	_spawn_destroy_fragments(block.global_position, block.get_color(), block.get_size())

## Cosmetic-only: the actual +1 doesn't land until the dropped ball visually
## reaches the floor -- see _on_powerup_ball_landed.
func _on_pickup_collected(pickup: BallPickup) -> void:
	var falling := FallingBall.new()
	effects_root.add_child(falling)
	falling.global_position = pickup.global_position
	falling.setup(rules.ball_radius, rules.floor_y)
	falling.landed.connect(_on_powerup_ball_landed)

func _on_powerup_ball_landed(_ball: FallingBall) -> void:
	pending_balls += 1
	_refresh_hud()

func _end_round() -> void:
	state = State.RESOLVING

	# The shooter follows the first ball home, the way the original does --
	# now a slide rather than a snap, with every other landed ball gathered
	# to the same spot along its own random arc rather than just vanishing.
	var target := Vector2(shooter.position.x, rules.floor_y - rules.shooter_height)
	if rules.balls_return_to_lander and _has_landing:
		target.x = _landing_x
		shooter.slide_to_x(target.x, SHOOTER_SLIDE_DURATION)
	for ball in _landed_balls:
		if is_instance_valid(ball):
			ball.return_to(target, randf_range(BALL_RETURN_MIN_DURATION, BALL_RETURN_MAX_DURATION))
	_landed_balls.clear()

	ball_count += pending_balls
	expected_ball_count += pending_balls
	expected_round_number += 1
	pending_balls = 0

	if debug_row_credit > 0:
		# Spend banked debug slack (see debug_shift_rows): shift only, no new
		# row, no round_number bump, until the credit runs out.
		debug_row_credit -= 1
		if grid.advance():
			_game_over()
			return
	else:
		# Spawn the next round's row into row 0 (still clear from last time)
		# and THEN shift -- not the other way around. advance() carries the
		# fresh spawn down into row 1 along with everything else, so row 0
		# reads as clear again once this settles. round_number only advances
		# on survival, so a loss is still reported against the round that was
		# just played.
		grid.spawn_row(round_number + 1)
		if grid.advance():
			_game_over()
			return
		round_number += 1

	shooter.active = true
	shooter.queue_redraw()
	state = State.AIMING
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
	debug_overlay.refresh_readouts()


# --------------------------------------------------------------- debug tools
# All gated behind Debug.enabled by the callers above (_process, _unhandled_
# input) -- these methods themselves don't re-check it, since the debug menu
# and overlay only exist to call them while it's on. Both the keyboard
# (arrows + Shift) and the on-screen D-pad drive these through the SAME named
# input actions (the overlay presses debug_up/down/left/right with
# Input.action_press), so there is exactly one place that interprets them.

func _on_debug_grid_apply(width: int, height: int, kill_row: int, spawn_row: int) -> void:
	rules.grid_width = maxi(1, width)
	rules.grid_height = maxi(2, height)
	rules.death_row_override = clampi(kill_row, 0, rules.grid_height - 1)
	rules.spawn_row_index = clampi(spawn_row, 0, rules.grid_height - 1)
	round_number = 1
	ball_count = 1
	expected_ball_count = 1
	expected_round_number = 1
	debug_row_credit = 0
	_layout_playfield()
	_prime_board()
	debug_overlay.refresh_row_buttons()
	_refresh_hud()

func _tick_debug_input(delta: float) -> void:
	var shift_held := Input.is_action_pressed("debug_shift_hold") or debug_overlay.touch_shift_toggled

	if Input.is_action_just_pressed("debug_up"):
		if shift_held:
			debug_shift_rows(1)
		else:
			debug_ball_count_delta(1)
	if Input.is_action_just_pressed("debug_down"):
		if shift_held:
			debug_shift_rows(-1)
		else:
			debug_ball_count_delta(-1)

	if shift_held:
		if Input.is_action_just_pressed("debug_left"):
			debug_round_delta(-1)
		if Input.is_action_just_pressed("debug_right"):
			debug_round_delta(1)
	else:
		var move := Input.get_axis("debug_left", "debug_right")
		if not is_zero_approx(move):
			debug_move_launch(move * DEBUG_MOVE_SPEED * delta)

	debug_overlay.refresh_readouts()

func debug_ball_count_delta(delta: int) -> void:
	ball_count = maxi(1, ball_count + delta)
	_refresh_hud()

func debug_round_delta(delta: int) -> void:
	round_number = maxi(1, round_number + delta)
	_refresh_hud()

## Shift the whole field up one row and bank a credit: the next `abs(delta)`
## real round-completions shift down without spawning a new row or advancing
## round_number, since an up-shift manufactures slack that normal play did
## not earn. A down-shift is a real shift too -- it can end the run exactly
## like a normal round's shift can.
func debug_shift_rows(delta: int) -> void:
	if delta > 0:
		grid.shift_up()
		debug_row_credit += 1
	elif delta < 0:
		if grid.advance():
			_game_over()
			return
		debug_row_credit = maxi(0, debug_row_credit - 1)
	_refresh_hud()

func debug_clear_row(row: int) -> void:
	grid.clear_row(row)

func debug_clear_all() -> void:
	grid.clear_all()

## While held, nudges the shooter (and any live balls) sideways without
## touching aim -- a debug-only way to reposition without waiting for a
## fresh round.
func debug_move_launch(delta_x: float) -> void:
	shooter.position.x = clampf(shooter.position.x + delta_x, _play_left, _play_right)
	for ball: Node in balls_root.get_children():
		if ball is Ball:
			(ball as Ball).global_position.x = clampf(
				(ball as Ball).global_position.x + delta_x,
				_play_left + rules.ball_radius,
				_play_right - rules.ball_radius
			)

## 1 damage, or a full-value destroy. Called from _unhandled_input when
## Debug.enabled and the click/tap lands on a Block.
func debug_damage_at(point: Vector2, destroy: bool) -> void:
	var block := grid.block_at(point)
	if block == null:
		return
	block.hit(block.value if destroy else 1)

## Best-effort two-finger tap: NOT verified on real touch hardware (no
## touch/Android build exists yet, docs/ROADMAP.md). A second concurrent
## touch that lands on a block destroys it outright, mirroring Shift+Click.
func _handle_debug_touch(t: InputEventScreenTouch) -> void:
	if t.pressed:
		_debug_touches[t.index] = t.position
		if _debug_touches.size() >= 2:
			var world := get_canvas_transform().affine_inverse() * t.position
			if grid.block_at(world) != null:
				debug_damage_at(world, true)
	else:
		_debug_touches.erase(t.index)


# --------------------------------------------------------------- playfield fx

## A handful of chunks popped upward/outward by a hit the block survived.
func _spawn_hit_chunks(pos: Vector2, color: Color, block_size: float) -> void:
	var count := randi_range(3, 5)
	for i in range(count):
		var chunk := BlockChunk.new()
		effects_root.add_child(chunk)
		chunk.position = pos
		var angle := randf_range(-PI * 0.85, -PI * 0.15) # mostly upward
		var speed := randf_range(120.0, 260.0)
		chunk.setup(
			color,
			block_size * randf_range(0.08, 0.16),
			Vector2.RIGHT.rotated(angle) * speed,
			randf_range(0.35, 0.55),
			randf_range(-6.0, 6.0)
		)

## Four quadrant-sized pieces cracking apart when a block is destroyed.
func _spawn_destroy_fragments(pos: Vector2, color: Color, block_size: float) -> void:
	for i in range(4):
		var frag := BlockFragment.new()
		effects_root.add_child(frag)
		var offset := Vector2(
			(float(i % 2) - 0.5) * block_size * 0.4,
			(float(i / 2) - 0.5) * block_size * 0.4
		)
		frag.position = pos + offset
		var outward := offset.normalized() if offset.length_squared() > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)
		var vel := outward * randf_range(60.0, 140.0) + Vector2(0.0, -randf_range(40.0, 90.0))
		frag.setup(color, block_size * 0.46, vel, randf_range(0.6, 0.9), randf_range(-4.0, 4.0))

func _draw() -> void:
	if rules == null:
		return
	var vp_w := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var vp_h := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	draw_rect(Rect2(Vector2.ZERO, Vector2(vp_w, vp_h)), Skins.background().color, true)

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
