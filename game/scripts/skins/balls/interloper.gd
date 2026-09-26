extends BallLook
## Interloper -- the comet: an ice-white core, a cyan tail, now and then a
## ghost-matter fleck. Unlocked by the title-screen constellation.

func _init() -> void:
	super("Interloper", Color("#e8f4ff"))
	highlight = Color(1, 1, 1, 0.8)
	trail_color = Color("#7fe3ff")
	fleck_chance = 0.12
	fleck_color = Color("#6dff8a")
	locked_by = Unlocks.OUTER_WILDS

func draw(c: CanvasItem, pos: Vector2, r: float, spin: float, _t: float) -> void:
	c.draw_circle(pos, r * 1.1, Color(0.5, 0.9, 1.0, 0.25))
	c.draw_circle(pos, r, color)
	for crack in [Vector2(0.3, -0.1), Vector2(-0.25, 0.3)]:
		c.draw_circle(pos + (crack * r).rotated(spin), r * 0.18, Color(0.75, 0.9, 1.0, 0.8))
	c.draw_circle(pos + Vector2(-r, -r) * 0.3, r * 0.3, highlight)
