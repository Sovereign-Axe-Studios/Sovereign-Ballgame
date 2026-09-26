extends BallLook
## Basketball -- pebbled orange with the classic four seams, rotating.

const ORANGE := Color("#e0782f")
const SEAM := Color("#2a1408")
const PEBBLES := 70

var _pebbles := PackedVector2Array()

func _init() -> void:
	super("Basketball", ORANGE)
	# Fixed pebble pattern (unit disc), spun with the ball.
	for i in range(PEBBLES):
		var a := i * 2.39996
		_pebbles.append(Vector2(cos(a), sin(a)) * sqrt(float(i) / PEBBLES) * 0.9)

func draw(c: CanvasItem, pos: Vector2, r: float, spin: float, _t: float) -> void:
	c.draw_circle(pos, r, ORANGE)
	for p in _pebbles:
		c.draw_circle(pos + (p * r).rotated(spin), maxf(0.8, r * 0.035), Color(0.35, 0.15, 0.04, 0.35))
	var w := maxf(1.5, r * 0.08)
	inside_line(c, pos, r, PackedVector2Array([Vector2(-r, 0), Vector2(r, 0)]), spin, SEAM, w)
	inside_line(c, pos, r, PackedVector2Array([Vector2(0, -r), Vector2(0, r)]), spin, SEAM, w)
	for side in [-1.0, 1.0]:
		var arc := PackedVector2Array()
		for k in range(13):
			var a := lerpf(-1.1, 1.1, k / 12.0)
			arc.append(Vector2(side * (r * 1.25 - cos(a) * r * 0.85), sin(a) * r * 0.85))
		inside_line(c, pos, r * 0.99, arc, spin, SEAM, w)
	shade(c, pos, r, 0.3, 0.3)
