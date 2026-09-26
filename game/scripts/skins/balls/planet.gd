extends BallLook
## Planet -- a banded sphere whose bands drift, inside a tilted ring.

const BODY := Color("#6f7de8")
const BAND_LIGHT := Color("#8e9cf5")
const BAND_DARK := Color("#5260c9")
const RING := Color("#f2c94c")
## Ring tilt, radians.
const TILT := -0.35

func _init() -> void:
	super("Planet", BODY)

func draw(c: CanvasItem, pos: Vector2, r: float, spin: float, _t: float) -> void:
	# Back half of the ring, behind the planet.
	c.draw_polyline(ellipse_points(pos, r * 1.6, r * 0.42, TILT, PI, TAU), Color(RING, 0.55), r * 0.12, true)
	c.draw_circle(pos, r, BODY)
	var scroll := fposmod(spin * r * 0.35, r * 0.5)
	for i in range(-3, 4):
		var y := -r + i * r * 0.5 + scroll
		band(c, pos, r, y, y + r * 0.22, TILT, BAND_LIGHT if i % 2 == 0 else BAND_DARK)
	shade(c, pos, r, 0.3, 0.35)
	c.draw_polyline(ellipse_points(pos, r * 1.6, r * 0.42, TILT, 0.0, PI), Color(RING, 0.9), r * 0.12, true)
