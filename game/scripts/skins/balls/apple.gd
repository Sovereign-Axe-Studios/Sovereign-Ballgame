extends BallLook
## Apple -- red into green, a stem and a leaf that wobbles. The stem stays
## up (a rolling apple with a spinning stem read as wrong).

const RED := Color("#d32f2f")
const DEEP := Color("#8e1b1b")
const GREEN := Color("#7cb342")

func _init() -> void:
	super("Apple", RED)

func draw(c: CanvasItem, pos: Vector2, r: float, _spin: float, t: float) -> void:
	c.draw_circle(pos, r, RED)
	c.draw_circle(pos + Vector2(r * 0.35, r * 0.25), r * 0.55, Color(GREEN, 0.35))
	c.draw_arc(pos, r * 0.88, 0.2, 2.2, 16, Color(DEEP, 0.5), r * 0.22, true)
	c.draw_circle(pos + Vector2(0, -r * 0.82), r * 0.2, DEEP)
	c.draw_line(pos + Vector2(0, -r * 0.8), pos + Vector2(r * 0.12, -r * 1.3), Color("#5d4037"), maxf(1.5, r * 0.12), true)
	var leaf_rot := -0.6 + sin(t * 2.0) * 0.25
	var leaf := ellipse_points(pos + Vector2(r * 0.35, -r * 1.12), r * 0.32, r * 0.14, leaf_rot, 0.0, TAU, 16)
	c.draw_colored_polygon(leaf, Color("#66bb6a"))
	shade(c, pos, r, 0.5, 0.2)
