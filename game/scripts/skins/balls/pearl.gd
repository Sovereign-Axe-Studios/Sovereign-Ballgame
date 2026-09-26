extends BallLook
## Pearl -- a soft iridescent sheen whose hue shifts as it moves.

func _init() -> void:
	super("Pearl", Color("#f3ecf7"))

func draw(c: CanvasItem, pos: Vector2, r: float, spin: float, t: float) -> void:
	var hue := fposmod(spin * 0.08 + t * 0.05, 1.0)
	c.draw_circle(pos, r, Color.from_hsv(hue, 0.08, 0.95))
	# Concentric sheen rings, each a little further round the hue wheel.
	for i in range(4):
		var f := 1.0 - i * 0.2
		var col := Color.from_hsv(fposmod(hue + i * 0.18, 1.0), 0.18, 0.98, 0.35)
		c.draw_circle(pos + Vector2(r * 0.12, r * 0.1) * i, r * f * 0.8, col)
	shade(c, pos, r, 0.85, 0.18)
