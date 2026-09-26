extends BallLook
## Meteor -- cratered rock with a burning edge, a fire trail and embers.

const ROCK := Color("#5b4a3e")
const CRATER := Color("#3d3129")
const FIRE := Color("#ffb347")
## Craters as (x, y, radius), fractions of the ball radius.
const CRATERS: Array[Vector3] = [
	Vector3(-0.3, -0.2, 0.24), Vector3(0.32, 0.25, 0.17), Vector3(0.1, -0.5, 0.12), Vector3(-0.2, 0.45, 0.1),
]

func _init() -> void:
	super("Meteor", Color("#ff8a3c"))
	trail_color = Color("#ff7a2e")
	fleck_chance = 0.35
	fleck_color = Color("#ffd27a")

func draw(c: CanvasItem, pos: Vector2, r: float, spin: float, t: float) -> void:
	c.draw_circle(pos, r * 1.08, Color(FIRE, 0.35 + 0.15 * sin(t * 12.0)))
	c.draw_circle(pos, r, ROCK)
	for crater in CRATERS:
		var p := Vector2(crater.x, crater.y).rotated(spin) * r
		c.draw_circle(pos + p, crater.z * r, CRATER)
	c.draw_arc(pos, r * 0.94, spin + 0.3, spin + 2.4, 16, Color(FIRE, 0.85), r * 0.12, true)
	shade(c, pos, r, 0.2, 0.25)
