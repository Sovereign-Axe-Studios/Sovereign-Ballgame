class_name Game
extends Node2D
## Round loop, playfield construction, and scoring.
##
## A round is: aim -> fire every ball -> wait for them all to land -> bank
## pickups -> shift the field down -> lose, or spawn the next row and aim again.

enum State { AIMING, FIRING, RESOLVING, GAME_OVER }

## The last block on the board was destroyed (once per clear).
signal board_cleared(at: Vector2)
## A +1 pickup's dropped ball landed.
signal new_ball(at: Vector2)

const BallScene := preload("res://scenes/ball.tscn")
const DEBUG_MOVE_SPEED := 700.0 ## px/sec for the debug left/right launch-position nudge.
const SHOOTER_SLIDE_DURATION := 0.28
const BALL_RETURN_MIN_DURATION := 0.32
const BALL_RETURN_MAX_DURATION := 0.5
const BALL_RETURN_STAGGER := 0.08 ## per-ball delay step for the ordered/random Stick variants.
const LINE_UP_SPACING := 50.0
## Audio: a block that spawned with at least this value breaks with the "big" sound.
const BIG_BLOCK_VALUE := 20
## Audio: the danger warning plays when a block is within this many rows of the death row.
const DANGER_ROWS := 2

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
var _landed_balls: Array[Ball] = [] ## Stick modes only -- finished but not yet freed, gathered in _end_round.
var _line_up_count: int = 0 ## reset each round; LINE_UP mode's next-slot counter.
var _rules_installed: bool = false
## What field hooks (GameMod.on_run_start / on_round_end) are handed.
var field := Playfield.new()
## +1 pickups still dropping. Credited at round end even if they haven't
## landed yet -- see _end_round.
var _falling_balls: Array[FallingBall] = []
var _animated_bg: AnimatedBackground
## Set once the board empties; cleared when blocks exist again, so
## board_cleared fires once per clear.
var _board_was_clear: bool = false
## Balls launched so far this round (SHOT_SPREAD's shot_index).
var _shots_fired: int = 0
## Seconds since this round's first shot (rules.on_firing_tick).
var _firing_time: float = 0.0


## Rules exist from _enter_tree, not _ready: children (DebugOverlay,
## PauseMenu) run their _ready BEFORE this node's, and some read `rules`.
func _enter_tree() -> void:
	if _rules_installed:
		return
	_rules_installed = true
	if rules == null:
		rules = GameRules.new()
	# Before layout: GRID mods change the board size.
	rules.install(Run.make_mods())

func _ready() -> void:
	randomize()

	grid.pickup_collected.connect(_on_pickup_collected)
	grid.block_destroyed.connect(_on_block_destroyed)
	pause_menu.grid_apply_requested.connect(_on_debug_grid_apply)
	Skins.changed.connect(queue_redraw)
	Skins.changed.connect(_sync_animated_background)
	_sync_animated_background()
	AudioLib.play_game_music(round_number)

	_layout_playfield()
	_prime_board()
	field.rules = rules
	field.grid = grid
	field.effects_root = effects_root
	rules.on_run_start(field)
	if Debug.enabled:
		debug_overlay.refresh_row_buttons()
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
	rules.play_left = _play_left
	rules.play_right = _play_right

	# Square cells. Width usually decides, but clamp so a taller grid (a mod
	# changing grid_height) still leaves the shooter room to work.
	var by_width := (_play_right - _play_left) / float(rules.grid_width)
	var free_height := (rules.floor_y - rules.shooter_height - 140.0) - rules.grid_top
	var by_height := free_height / float(rules.grid_height)
	var cell := minf(by_width, by_height)

	var grid_w := cell * float(rules.grid_width)
	var org := Vector2((vp.x - grid_w) * 0.5, rules.grid_top)
	grid.configure(rules, cell, org)

	Playfield.build_walls(walls_root, rules, vp.x)

	shooter.setup(rules)
	shooter.position = Vector2(vp.x * 0.5, rules.floor_y - rules.shooter_height)
	queue_redraw()

## Spawn round 1's row into row 0, then shift it into row 1 immediately -- the
## same spawn-then-shift sequence _end_round uses -- so row 0 reads as clear
## from the very first frame, not just after the first round ends. Re-run
## after a debug grid-size apply too, since that clears the whole board.
func _prime_board() -> void:
	rules.seed_field(round_number)
	grid.spawn_row(round_number)
	grid.advance()


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
			_firing_time += delta
			rules.on_firing_tick(self, _firing_time)
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
			# A release past the allowed aim range cancels the shot instead
			# of firing at the clamped angle -- an overdrag reads as "changed
			# my mind", not "fire sideways".
			var raw := shooter.raw_aim_degrees(get_global_mouse_position())
			if absf(raw) <= rules.max_aim_degrees:
				_begin_firing()
	elif event is InputEventMouseMotion and _dragging:
		shooter.aim_at(get_global_mouse_position())


# ---------------------------------------------------------------- round loop

func _begin_firing() -> void:
	state = State.FIRING
	_firing_time = 0.0
	_to_fire = rules.shots_for_round(ball_count)
	_shots_fired = 0
	rules.seed_shots(round_number)
	_fire_cd = 0.0
	_live_balls = 0
	_has_landing = false
	_line_up_count = 0
	round_damage = 0
	_fire_origin = shooter.global_position
	# Deliberately NOT shooter.active = false -- it keeps showing the aim line
	# at the angle it just fired, so it reads as "pointing where it last
	# shot" rather than going dark. Input is already gated by `state`, not by
	# `active`, so this doesn't let the player re-aim mid-round.
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

## An animated background skin is a node drawn behind this one, not a flat
## fill in _draw. Swap it to match the current skin.
func _sync_animated_background() -> void:
	var want: GDScript = Skins.background().scene
	if is_instance_valid(_animated_bg) and _animated_bg.get_script() == want:
		return
	if is_instance_valid(_animated_bg):
		_animated_bg.queue_free()
		_animated_bg = null
	if want != null:
		_animated_bg = want.new() as AnimatedBackground
		add_child(_animated_bg)
		move_child(_animated_bg, 0)

## Cancel this round's unfired shots (Time Rewind). The round still ends the
## normal way, once every ball already out has finished.
func stop_firing() -> void:
	_to_fire = 0
	if _live_balls <= 0 and state == State.FIRING:
		_end_round()

## Balls still in play this round.
func live_balls() -> Array[Ball]:
	var out: Array[Ball] = []
	for node in balls_root.get_children():
		if node is Ball and not (node as Ball).is_done():
			out.append(node)
	return out

func _spawn_ball() -> void:
	var ball: Ball = BallScene.instantiate()
	balls_root.add_child(ball)
	ball.launch(rules, _fire_origin, rules.shot_direction(shooter.aim_direction(), _shots_fired))
	_shots_fired += 1
	shooter.flash()
	ball.finished.connect(_on_ball_finished)
	ball.block_damaged.connect(_on_block_damaged)
	ball.wall_bounced.connect(AudioLib.play_sfx.bind("bounce"))
	AudioLib.play_sfx("launch")
	_live_balls += 1

func _on_ball_finished(ball: Ball) -> void:
	_live_balls -= 1
	AudioLib.play_sfx("land")
	if not _has_landing:
		_has_landing = true
		_landing_x = clampf(
			ball.global_position.x,
			_play_left + rules.ball_radius,
			_play_right - rules.ball_radius
		)
		# The shooter follows the FIRST ball home immediately, not at the end
		# of the round -- the original waited for every ball to land first.
		if rules.balls_return_to_lander:
			shooter.slide_to_x(_landing_x, SHOOTER_SLIDE_DURATION)

	match Skins.return_mode:
		Skins.ReturnMode.MOVE_TO_SHOOTER:
			ball.return_to(_launch_target(), randf_range(BALL_RETURN_MIN_DURATION, BALL_RETURN_MAX_DURATION))
		Skins.ReturnMode.LINE_UP:
			# Parks in its slot (not freed) and waits in _landed_balls; the
			# whole line gathers to the shooter in _end_round.
			ball.return_to(_next_line_up_slot(), randf_range(BALL_RETURN_MIN_DURATION, BALL_RETURN_MAX_DURATION),
				0.0, false)
			_landed_balls.append(ball)
		_:
			# STICK_* -- frozen where it landed until _end_round moves it.
			_landed_balls.append(ball)

	if _to_fire <= 0 and _live_balls <= 0:
		_end_round()

## Where a gathering ball is headed: the shooter's X if balls_return_to_lander
## is off or nothing has landed yet, otherwise the shared landing spot.
func _launch_target() -> Vector2:
	var x := shooter.position.x
	if rules.balls_return_to_lander and _has_landing:
		x = _landing_x
	return Vector2(x, rules.floor_y - rules.shooter_height)

## The next slot in LINE_UP mode's queue, in the strip below the floor line.
func _next_line_up_slot() -> Vector2:
	var slot := _line_up_count
	_line_up_count += 1
	var center_x := (_play_left + _play_right) * 0.5
	# Squeeze the spacing so the whole round's balls fit between the walls,
	# instead of clamping the overflow into a pile at each end.
	var count := maxi(1, rules.shots_for_round(ball_count))
	var span := (_play_right - _play_left) - rules.ball_radius * 2.0
	var spacing := minf(LINE_UP_SPACING, span / float(maxi(1, count - 1)))
	var x := center_x + (float(slot) - float(count - 1) * 0.5) * spacing
	return Vector2(clampf(x, _play_left, _play_right), rules.floor_y + 26.0)

func _on_block_damaged(block: Block, damage: int) -> void:
	round_damage += damage
	total_damage += damage
	AudioLib.play_sfx("hit")
	if is_instance_valid(block) and block.value > 0:
		_spawn_hit_chunks(block.global_position, block.get_color(), block.get_size())
	_refresh_hud()

func _on_block_destroyed(block: Block) -> void:
	AudioLib.play_sfx("break_big" if block.start_value >= BIG_BLOCK_VALUE else "break_small")
	_spawn_destroy_fragments(block.global_position, block.get_color(), block.get_size())
	if not _board_was_clear and grid.block_count() == 0:
		_board_was_clear = true
		board_cleared.emit(block.global_position)
		if is_instance_valid(_animated_bg):
			_animated_bg.on_board_cleared(block.global_position)

## Cosmetic-only: the actual +1 doesn't land until the dropped ball visually
## reaches the floor -- see _on_powerup_ball_landed.
func _on_pickup_collected(pickup: BallPickup) -> void:
	AudioLib.play_sfx("pickup")
	var falling := FallingBall.new()
	effects_root.add_child(falling)
	falling.global_position = pickup.global_position
	falling.setup(rules.ball_radius, rules.floor_y)
	falling.landed.connect(_on_powerup_ball_landed)
	_falling_balls.append(falling)

## Only ticks pending_balls if _end_round hasn't already credited this ball
## (it does when the round's balls all land before the pickup does).
func _on_powerup_ball_landed(ball: FallingBall) -> void:
	_falling_balls.erase(ball)
	new_ball.emit(ball.global_position)
	if is_instance_valid(_animated_bg):
		_animated_bg.on_new_ball(ball.global_position)
	if ball.credited:
		return
	pending_balls += 1
	_refresh_hud()

func _end_round() -> void:
	state = State.RESOLVING

	# MOVE_TO_SHOOTER / LINE_UP balls already started gathering the instant
	# they landed (_on_ball_finished) -- _landed_balls only holds the STICK_*
	# modes' balls, frozen where they landed until now.
	var target := _launch_target()
	match Skins.return_mode:
		Skins.ReturnMode.STICK_ORDERED:
			for i in range(_landed_balls.size()):
				var ball := _landed_balls[i]
				if is_instance_valid(ball):
					ball.return_to(target, randf_range(BALL_RETURN_MIN_DURATION, BALL_RETURN_MAX_DURATION), i * BALL_RETURN_STAGGER)
		Skins.ReturnMode.STICK_RANDOM:
			var shuffled := _landed_balls.duplicate()
			shuffled.shuffle()
			for i in range(shuffled.size()):
				var ball: Ball = shuffled[i]
				if is_instance_valid(ball):
					ball.return_to(target, randf_range(BALL_RETURN_MIN_DURATION, BALL_RETURN_MAX_DURATION), i * BALL_RETURN_STAGGER)
		_:
			for ball in _landed_balls:
				if is_instance_valid(ball):
					ball.return_to(target, randf_range(BALL_RETURN_MIN_DURATION, BALL_RETURN_MAX_DURATION))
	_landed_balls.clear()

	# A pickup collected this round counts this round, even if its dropped
	# ball is still falling -- otherwise it would bank into the NEXT round's
	# pending and the player waits an extra round for it.
	for falling in _falling_balls:
		if not falling.credited:
			falling.credited = true
			pending_balls += 1
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
		# The SPAWN_DIRECTION mod owns this step; the stock one spawns into
		# row 0 then shifts everything down (see GameMod.advance_field).
		if rules.advance_field(grid, round_number):
			_game_over()
			return
		round_number += 1
		AudioLib.set_round(round_number)
	AudioLib.play_sfx("row_shift")
	if _blocks_near_death():
		AudioLib.play_sfx("danger")
	rules.on_round_end(field)
	if grid.block_count() > 0:
		_board_was_clear = false

	shooter.active = true
	shooter.queue_redraw()
	state = State.AIMING
	_refresh_hud()

func _game_over() -> void:
	state = State.GAME_OVER
	AudioLib.stop_music(1.2)
	AudioLib.play_sfx("game_over")
	shooter.active = false
	shooter.queue_redraw()
	print("DEBUG: lose game -- a block reached row %d on round %d (total damage %d)"
		% [rules.death_row(), round_number, total_damage])
	hud.show_game_over(round_number, total_damage)

## True when any block has crept to within DANGER_ROWS of the death row.
func _blocks_near_death() -> bool:
	var first_danger_row := rules.death_row() - DANGER_ROWS
	for row in range(maxi(0, first_danger_row), grid.cells.size()):
		for item in grid.cells[row]:
			if item is Block:
				return true
	return false

func _refresh_hud() -> void:
	hud.refresh(round_number, ball_count, pending_balls, round_damage, total_damage, rules.status_lines())
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
	rules.on_run_start(field)
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
	AudioLib.set_round(round_number)
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

## A cols x rows grid of pieces cracking apart when a block is destroyed --
## cols/rows are each a random pick in GameRules' [MIN, MAX] range (a fixed
## 2x2 if MIN == MAX for both), debug-menu adjustable.
func _spawn_destroy_fragments(pos: Vector2, color: Color, block_size: float) -> void:
	var cols := randi_range(mini(rules.fragment_cols_min, rules.fragment_cols_max), maxi(rules.fragment_cols_min, rules.fragment_cols_max))
	var rows := randi_range(mini(rules.fragment_rows_min, rules.fragment_rows_max), maxi(rules.fragment_rows_min, rules.fragment_rows_max))
	cols = maxi(1, cols)
	rows = maxi(1, rows)
	var piece_size := Vector2(block_size / float(cols), block_size / float(rows)) * 0.92
	for row in range(rows):
		for col in range(cols):
			var frag := BlockFragment.new()
			effects_root.add_child(frag)
			var offset := Vector2(
				(float(col) - float(cols - 1) * 0.5) * block_size / float(cols),
				(float(row) - float(rows - 1) * 0.5) * block_size / float(rows)
			)
			frag.position = pos + offset
			var outward := offset.normalized() if offset.length_squared() > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)
			var vel := outward * randf_range(60.0, 140.0) + Vector2(0.0, -randf_range(40.0, 90.0))
			frag.setup(color, piece_size, vel, randf_range(0.6, 0.9), randf_range(-4.0, 4.0))

func _draw() -> void:
	if rules == null:
		return
	var vp_w := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var vp_h := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	if Skins.background().scene == null:
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
