extends BallLook
## Golf ball -- a hex grid of dimples that scrolls as it rolls, deeper
## toward the edge, with soft shading.

const SPACING := 0.3   ## dimple spacing, fraction of radius

func _init() -> void:
	super("Golf Ball", Color("#f4f4ee"))

func draw(c: CanvasItem, pos: Vector2, r: float, spin: float, _t: float) -> void:
	c.draw_circle(pos, r, Color("#f4f4ee"))
	var s := r * SPACING
	var off := fposmod(spin * r * 0.5, s)
	for j in range(-5, 6):
		for i in range(-5, 6):
			var local := Vector2(i * s + (s * 0.5 if j % 2 != 0 else 0.0) - off, j * s * 0.87)
			var d := local.length() / r
			if d >= 0.92:
				continue
			# Foreshortened toward the rim, like a real sphere.
			var dimple := r * 0.075 * (1.0 - d * 0.45)
			c.draw_circle(pos + local, dimple, Color(0.35, 0.35, 0.3, 0.16 + 0.26 * d))
	shade(c, pos, r, 0.55, 0.28)
