class_name Shooter
extends Node2D
## The aim line. 0 degrees is straight up, positive is clockwise (to the right).

var rules: GameRules
var aim_degrees: float = 0.0
var active: bool = true

func setup(r: GameRules) -> void:
	rules = r
	queue_redraw()

func aim_direction() -> Vector2:
	return Vector2.UP.rotated(deg_to_rad(aim_degrees))

func nudge(degrees: float) -> void:
	set_aim(aim_degrees + degrees)

func set_aim(degrees: float) -> void:
	var limit := rules.max_aim_degrees if rules else 78.0
	var clamped := clampf(degrees, -limit, limit)
	if not is_equal_approx(clamped, aim_degrees):
		aim_degrees = clamped
		queue_redraw()

## Point the line at a world position, respecting the clamp. Used by mouse aim.
func aim_at(world_point: Vector2) -> void:
	var to_point := world_point - global_position
	if to_point.length_squared() < 4.0:
		return
	set_aim(rad_to_deg(Vector2.UP.angle_to(to_point)))

func _draw() -> void:
	var base := Palette.BALL
	draw_circle(Vector2.ZERO, 22.0, base if active else base.darkened(0.5))
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, Palette.WALL.lightened(0.3), 3.0, true)
	if not active:
		return
	var dir := aim_direction()
	for i in range(2, 20):
		var alpha := clampf(0.85 - float(i) * 0.04, 0.05, 0.85)
		draw_circle(dir * (float(i) * 36.0), 5.0, Color(base.r, base.g, base.b, alpha))
