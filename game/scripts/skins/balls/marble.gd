extends BallLook
## Marble -- clear glass with two coloured swirls turning inside.

const GLASS := Color(0.55, 0.8, 1.0, 0.45)
const SWIRL_A := Color("#e5533d")
const SWIRL_B := Color("#f2c94c")

func _init() -> void:
	super("Marble", Color("#8fd0ff"))

func draw(c: CanvasItem, pos: Vector2, r: float, spin: float, _t: float) -> void:
	c.draw_circle(pos, r, GLASS)
	for k in range(2):
		var pts := PackedVector2Array()
		var a := 0.0
		while a < 6.0:
			var rr := a * r * (0.13 if k == 0 else 0.11)
			var ang := a + (0.0 if k == 0 else PI)
			pts.append(Vector2(cos(ang), sin(ang)) * rr)
			a += 0.15
		inside_line(c, pos, r * 0.9, pts, spin, SWIRL_A if k == 0 else SWIRL_B, r * (0.18 if k == 0 else 0.12))
	c.draw_arc(pos, r, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 1.5, true)
	shade(c, pos, r, 0.7, 0.15)
