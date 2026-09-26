extends BallLook
## Beach ball -- six coloured panels that spin as it rolls, a white cap.

const PANELS: Array[Color] = [
	Color("#e5533d"), Color("#ffffff"), Color("#2f80ed"),
	Color("#ffffff"), Color("#f2c94c"), Color("#ffffff"),
]

func _init() -> void:
	super("Beach Ball", Color("#f2c94c"))

func draw(c: CanvasItem, pos: Vector2, r: float, spin: float, _t: float) -> void:
	for i in range(PANELS.size()):
		var a0 := spin + i * TAU / PANELS.size()
		wedge(c, pos, r, a0, a0 + TAU / PANELS.size(), PANELS[i])
	c.draw_circle(pos, r * 0.18, Color.WHITE)
	shade(c, pos, r, 0.35, 0.22)
