class_name Shooter
extends Node2D
## The aim line. 0 degrees is straight up, positive is clockwise (to the right).

var rules: GameRules
var aim_degrees: float = 0.0
var active: bool = true

func _ready() -> void:
	Skins.changed.connect(queue_redraw)

func setup(r: GameRules) -> void:
	rules = r
	queue_redraw()

func aim_direction() -> Vector2:
	return Vector2.UP.rotated(deg_to_rad(aim_degrees))

## Cosmetic slide to a new X, used when the round hands the shooter to
## wherever the first ball landed -- an instant snap read as a glitch.
func slide_to_x(x: float, duration: float) -> void:
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "position:x", x, duration)

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
	var base := Skins.ball().color
	draw_circle(Vector2.ZERO, 22.0, base if active else base.darkened(0.5))
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, Palette.WALL.lightened(0.3), 3.0, true)
	if not active:
		return
	var dir := aim_direction()
	for i in range(2, 20):
		var alpha := clampf(0.85 - float(i) * 0.04, 0.05, 0.85)
		draw_circle(dir * (float(i) * 36.0), 5.0, Color(base.r, base.g, base.b, alpha))
