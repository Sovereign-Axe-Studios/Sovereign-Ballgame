class_name Ball
extends CharacterBody2D
## Constant-speed reflector. Deliberately not a RigidBody2D: we want the same
## bounce every time, no restitution drift, no sleeping, no gravity surprises.

signal finished(ball: Ball)                       ## crossed the floor, or timed out
signal block_damaged(block: Block, damage: int)
signal wall_bounced                               ## reflected off a side wall or the ceiling (Game plays the sound; previews stay silent)

var rules: GameRules
var direction := Vector2.UP
## Bounces so far (walls and blocks), counted after each contact's damage.
## Generic ball state for BALL_COLLISION mods (Snowball today).
var bounces: int = 0
## Side-wall bounces only (Bounce Pierce counts these).
var side_bounces: int = 0
## Per-ball mod state (Bounce Pierce: blocks already pierced).
var mod_state: Dictionary = {}
var _return_tween: Tween
## Tint while rewinding (Time Rewind).
const REWIND_COLOR := Color("#6fb6ff")
## Path recording cap, in points (one per physics frame): 30 s at 120 Hz.
const MAX_PATH_POINTS := 3600
## One point per physics frame, only when rules.wants_path_recording().
var _recording: bool = false
var _path := PackedVector2Array()
var _rewinding: bool = false
var _rewind_cursor: float = 0.0
var _rewind_speed: float = 1.0
## How far the ball has rolled, radians (distance / radius) -- ball looks
## rotate their surface detail by it.
var spin: float = 0.0
var _last_pos := Vector2.ZERO
## Recent global positions for a look's tail, newest last.
const TRAIL_POINTS := 10
var _trail := PackedVector2Array()
## Ghost-matter flecks in the tail: [global position, seconds left].
var _flecks: Array = []
var _age := 0.0
var _done := false

@onready var _shape: CollisionShape2D = $Collision

func _ready() -> void:
	Skins.changed.connect(queue_redraw)

func launch(r: GameRules, from: Vector2, dir: Vector2) -> void:
	rules = r
	global_position = from
	_last_pos = from
	direction = dir.normalized()
	_recording = r.wants_path_recording()
	r.configure_ball(self)
	if _recording:
		_path.append(from)
	var circle := CircleShape2D.new()
	circle.radius = r.ball_radius
	_shape.shape = circle
	queue_redraw()

## Cosmetic-only: slides this (already finished, no-longer-colliding) ball
## along a randomly-arced path to `target`, then frees it. Used once all
## balls are down, to visually gather them at the new launch position rather
## than having them just vanish where they landed -- see Game._end_round.
## `delay` staggers the START of the movement (Skins.ReturnMode's ordered /
## random variants); the ball still sits frozen at its landing spot until then.
## `free_on_arrival = false` parks it at `target` instead (LINE_UP waits in
## its slot until the round resolves); a later return_to replaces the move.
func return_to(target: Vector2, duration: float, delay: float = 0.0, free_on_arrival: bool = true) -> void:
	if _return_tween != null and _return_tween.is_valid():
		_return_tween.kill()
	var start := global_position
	if start.distance_to(target) < 1.0:
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout
		if free_on_arrival:
			queue_free()
		return
	var arc := randf_range(30.0, 120.0)
	var control := (start + target) * 0.5 + Vector2(0.0, -arc)
	var tw := create_tween()
	_return_tween = tw
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(
		func(t: float) -> void:
			var a := start.lerp(control, t)
			var b := control.lerp(target, t)
			global_position = a.lerp(b, t),
		0.0, 1.0, duration
	)
	if free_on_arrival:
		tw.tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	if _done or rules == null:
		return
	if _rewinding:
		_step_rewind()
		return

	_age += delta
	if _age >= rules.ball_max_lifetime:
		_finish()
		return

	# Step the whole frame's travel, consuming it across each bounce so a ball
	# that clips a corner still covers its full distance this tick.
	var remaining := rules.ball_speed * delta
	var guard := 0
	while remaining > 0.0 and guard < 8:
		guard += 1
		var collision := move_and_collide(direction * remaining)
		if collision == null:
			break
		remaining = maxf(0.0, remaining - collision.get_travel().length())

		var normal := collision.get_normal()
		var collider := collision.get_collider()
		var is_wall := collider is Node and (collider as Node).is_in_group("wall")
		# A WALL mod may take the contact over (Wrap Around teleports the
		# ball); it then skips the bounce entirely.
		if is_wall and rules.on_wall_hit(self, collision):
			continue
		direction = direction.bounce(normal).normalized()

		if collider is Block:
			var block := collider as Block
			var dealt: int = block.hit(rules.damage_for(self))
			block_damaged.emit(block, dealt)
			rules.on_block_hit(self, block)
		elif is_wall:
			_apply_corner_jitter(collision.get_position())
			wall_bounced.emit()
			if absf(normal.x) > 0.5:
				side_bounces += 1
		bounces += 1
		queue_redraw()

		_enforce_vertical()
		# Ease off the surface so the next substep does not start embedded.
		global_position += normal * 0.5

	rules.on_ball_moved(self)
	spin += global_position.distance_to(_last_pos) / maxf(1.0, rules.ball_radius) * signf(direction.x + 0.001)
	_last_pos = global_position
	_update_trail(delta)
	queue_redraw()
	if _recording and _path.size() < MAX_PATH_POINTS:
		_path.append(global_position)
	if global_position.y >= rules.floor_y:
		_finish()

## Time Rewind: play the recorded path backwards at `speed` x real time. The
## ball stops colliding (it's moved directly, never via move_and_collide) and
## finishes normally when it reaches where it was fired from.
func start_rewind(speed: float) -> void:
	if _done or _path.is_empty():
		return
	_rewinding = true
	_rewind_speed = speed
	_rewind_cursor = float(_path.size() - 1)
	queue_redraw()

## End this ball now (a mod's rule, e.g. Bounce Pierce's bounce limit).
func finish() -> void:
	_finish()

func is_done() -> bool:
	return _done

func is_rewinding() -> bool:
	return _rewinding

func _step_rewind() -> void:
	_rewind_cursor -= _rewind_speed
	if _rewind_cursor <= 0.0:
		global_position = _path[0]
		_finish()
		return
	var i := int(_rewind_cursor)
	global_position = _path[i].lerp(_path[mini(i + 1, _path.size() - 1)], _rewind_cursor - float(i))

## Near a corner, scatter the bounce slightly. Keeps balls from locking into a
## perfect repeating path, and gives corner shots the feel the spec asks for.
func _apply_corner_jitter(point: Vector2) -> void:
	if rules.corner_jitter_degrees <= 0.0:
		return
	var left := rules.play_left
	var right := rules.play_right
	var corners := [
		Vector2(left, rules.grid_top),
		Vector2(right, rules.grid_top),
		Vector2(left, rules.floor_y),
		Vector2(right, rules.floor_y),
	]
	var nearest := INF
	for c: Vector2 in corners:
		nearest = minf(nearest, point.distance_to(c))
	if nearest > rules.corner_radius:
		return
	var strength := 1.0 - (nearest / rules.corner_radius)
	var jitter := deg_to_rad(rules.shot_rng.randf_range(-1.0, 1.0) * rules.corner_jitter_degrees * strength)
	direction = direction.rotated(jitter).normalized()

## Stop balls settling into a flat horizontal groove they can never leave.
func _enforce_vertical() -> void:
	var min_y := rules.ball_min_vertical
	if absf(direction.y) >= min_y:
		return
	var sign_y := signf(direction.y) if direction.y != 0.0 else 1.0
	direction.y = min_y * sign_y
	direction = direction.normalized()

func _update_trail(delta: float) -> void:
	var skin := Skins.ball()
	if skin.trail_color.a <= 0.0:
		if not _trail.is_empty():
			_trail.clear()
			_flecks.clear()
		return
	_trail.append(global_position)
	if _trail.size() > TRAIL_POINTS:
		_trail.remove_at(0)
	if randf() < skin.fleck_chance and _trail.size() > 2:
		_flecks.append([_trail[randi_range(0, _trail.size() - 2)], 0.4])
	for fleck: Array in _flecks:
		# Flecks drift back and out, embers and flakes alike.
		fleck[0] = (fleck[0] as Vector2) + Vector2(randf_range(-20, 20), randf_range(-20, 20)) * delta
	for fleck: Array in _flecks:
		fleck[1] = float(fleck[1]) - delta
	_flecks = _flecks.filter(func(fk: Array) -> bool: return float(fk[1]) > 0.0)
	queue_redraw()

func _finish() -> void:
	if _done:
		return
	_done = true
	set_physics_process(false)
	finished.emit(self)

func _draw() -> void:
	if rules == null:
		return
	var skin := Skins.ball()
	var radius := rules.ball_radius * rules.ball_draw_scale(self)
	if skin.trail_color.a > 0.0 and _trail.size() > 1:
		for i in range(_trail.size() - 1):
			var f := float(i + 1) / float(_trail.size())
			draw_line(to_local(_trail[i]), to_local(_trail[i + 1]),
				Color(skin.trail_color, f * 0.8), radius * 1.6 * f, true)
		for fleck: Array in _flecks:
			draw_circle(to_local(fleck[0]), radius * 0.25, Color(skin.fleck_color, float(fleck[1]) / 0.4))
	if _rewinding:
		draw_circle(Vector2.ZERO, radius, REWIND_COLOR)
	else:
		skin.draw(self, Vector2.ZERO, radius, spin, _age)
	BallLook.contrast_ring(self, Vector2.ZERO, radius)
	rules.draw_ball_overlay(self, radius)
