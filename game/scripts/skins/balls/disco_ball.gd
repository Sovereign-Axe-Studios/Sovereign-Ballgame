extends BallLook
## Disco ball -- a grid of mirror facets that glint as it turns.

const BASE := Color("#9aa4b1")

func _init() -> void:
	super("Disco Ball", Color("#cfd6df"))

func draw(c: CanvasItem, pos: Vector2, r: float, spin: float, t: float) -> void:
	c.draw_circle(pos, r, BASE)
	var s := r / 2.6
	for i in range(-3, 4):
		for j in range(-3, 4):
			var local := Vector2(i * s, j * s)
			if local.length() > r * 0.88:
				continue
			var f := sin(t * 5.0 + spin * 2.0 + i * 1.7 + j * 2.3)
			var col := Color("#ffffff") if f > 0.85 else (Color("#cfd6df") if f > 0.2 else Color("#7d8793"))
			c.draw_rect(Rect2(pos + local - Vector2.ONE * s * 0.42, Vector2.ONE * s * 0.84), col, true)
	shade(c, pos, r, 0.25, 0.3)
