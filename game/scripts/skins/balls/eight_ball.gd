extends BallLook
## 8-ball -- black, with the numbered disc rolling round as it moves.

func _init() -> void:
	super("8-Ball", Color("#e6ebf2"))

func draw(c: CanvasItem, pos: Vector2, r: float, spin: float, _t: float) -> void:
	c.draw_circle(pos, r, Color("#111317"))
	# The disc slides across the face and round the back as the ball rolls;
	# it squashes near the edge so it reads as curving away.
	var along := sin(spin)
	var facing := cos(spin)
	if facing > -0.2:
		var center := pos + Vector2(along * r * 0.55, -r * 0.08)
		var squash := clampf(facing, 0.25, 1.0)
		var pts := ellipse_points(center, r * 0.42 * squash, r * 0.42, 0.0, 0.0, TAU)
		c.draw_colored_polygon(pts, Color.WHITE)
		if facing > 0.35:
			PreviewDraw.text(c, center, "8", int(r * 0.6), Color("#111317"))
	shade(c, pos, r, 0.45, 0.2)
