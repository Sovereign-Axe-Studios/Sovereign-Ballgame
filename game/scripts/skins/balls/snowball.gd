extends BallLook
## Snowball -- packed snow with blue-grey lumps, a glint, shedding flakes.

func _init() -> void:
	super("Snowball", Color("#eef4fb"))
	trail_color = Color(1, 1, 1, 0.25)
	fleck_chance = 0.3
	fleck_color = Color.WHITE

func draw(c: CanvasItem, pos: Vector2, r: float, spin: float, t: float) -> void:
	c.draw_circle(pos, r, Color("#eef4fb"))
	for i in range(8):
		var a := i * 1.9
		var p := Vector2(cos(a), sin(a)) * r * ((i % 3 + 1) / 4.2)
		c.draw_circle(pos + p.rotated(spin), r * 0.17, Color(0.67, 0.76, 0.88, 0.45))
	shade(c, pos, r, 0.4, 0.2)
	var glint := sin(t * 4.0)
	if glint > 0.6:
		c.draw_circle(pos + Vector2(-r * 0.3, -r * 0.4), r * 0.12 * glint, Color.WHITE)
