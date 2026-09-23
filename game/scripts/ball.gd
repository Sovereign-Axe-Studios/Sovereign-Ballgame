class_name Ball
extends CharacterBody2D
## Constant-speed reflector. Deliberately not a RigidBody2D: we want the same
## bounce every time, no restitution drift, no sleeping, no gravity surprises.

signal finished(ball: Ball)                       ## crossed the floor, or timed out
signal block_damaged(block: Block, damage: int)

var rules: GameRules
var direction := Vector2.UP
var _age := 0.0
var _done := false

@onready var _shape: CollisionShape2D = $Collision

func _ready() -> void:
	Skins.changed.connect(queue_redraw)

func launch(r: GameRules, from: Vector2, dir: Vector2) -> void:
	rules = r
	global_position = from
	direction = dir.normalized()
	var circle := CircleShape2D.new()
	circle.radius = r.ball_radius
	_shape.shape = circle
	queue_redraw()

## Cosmetic-only: slides this (already finished, no-longer-colliding) ball
## along a randomly-arced path to `target`, then frees it. Used once all
## balls are down, to visually gather them at the new launch position rather
## than having them just vanish where they landed -- see Game._end_round.
func return_to(target: Vector2, duration: float) -> void:
	var start := global_position
	if start.distance_to(target) < 1.0:
		queue_free()
		return
	var arc := randf_range(30.0, 120.0)
	var control := (start + target) * 0.5 + Vector2(0.0, -arc)
	var tw := create_tween()
	tw.tween_method(
		func(t: float) -> void:
			var a := start.lerp(control, t)
			var b := control.lerp(target, t)
			global_position = a.lerp(b, t),
		0.0, 1.0, duration
	)
	tw.tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	if _done or rules == null:
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
		direction = direction.bounce(normal).normalized()

		if collider is Block:
			var dealt: int = (collider as Block).hit(rules.ball_damage)
			block_damaged.emit(collider, dealt)
		elif collider is Node and (collider as Node).is_in_group("wall"):
			_apply_corner_jitter(collision.get_position())

		_enforce_vertical()
		# Ease off the surface so the next substep does not start embedded.
		global_position += normal * 0.5

	if global_position.y >= rules.floor_y:
		_finish()

## Near a corner, scatter the bounce slightly. Keeps balls from locking into a
## perfect repeating path, and gives corner shots the feel the spec asks for.
func _apply_corner_jitter(point: Vector2) -> void:
	if rules.corner_jitter_degrees <= 0.0:
		return
	var left := rules.side_margin
	var right := float(ProjectSettings.get_setting("display/window/size/viewport_width")) - rules.side_margin
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
	var jitter := deg_to_rad(randf_range(-1.0, 1.0) * rules.corner_jitter_degrees * strength)
	direction = direction.rotated(jitter).normalized()

## Stop balls settling into a flat horizontal groove they can never leave.
func _enforce_vertical() -> void:
	var min_y := rules.ball_min_vertical
	if absf(direction.y) >= min_y:
		return
	var sign_y := signf(direction.y) if direction.y != 0.0 else 1.0
	direction.y = min_y * sign_y
	direction = direction.normalized()

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
	draw_circle(Vector2.ZERO, rules.ball_radius, skin.color)
	draw_circle(Vector2(-rules.ball_radius * 0.3, -rules.ball_radius * 0.3), rules.ball_radius * 0.3, skin.highlight)
