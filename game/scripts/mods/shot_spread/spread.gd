extends GameMod
## Spread -- each shot leaves at the aim angle plus a random wobble.
## Value-only: the wobble itself is already built into Game._spawn_ball via
## `GameRules.random_rotate_value_deg`; this mod just turns it up.

## Max wobble either side of the aim line, in degrees.
const SPREAD_DEGREES := 6.0

func _init() -> void:
	category = Category.SHOT_SPREAD
	display_name = "Spread"
	description = "Each shot fires at the aim angle ±%s° of random variation." % SPREAD_DEGREES

func apply(rules: GameRules) -> void:
	rules.random_rotate_value_deg = SPREAD_DEGREES

## A fan of shots wobbling around the aim line.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var origin := PreviewDraw.at(r, 0.5, 0.88)
	var aim := Vector2.UP.rotated(deg_to_rad(12.0))
	c.draw_line(origin, origin + aim * PreviewDraw.px(r, 0.7), PreviewDraw.FRAME, 2.0)
	var offsets := [-1.0, -0.4, 0.3, 0.9, -0.7]
	for i in range(offsets.size()):
		var dir := aim.rotated(deg_to_rad(SPREAD_DEGREES * 2.5 * offsets[i]))
		var f := PreviewDraw.phase(t + i * 0.25, 1.25)
		PreviewDraw.ball(c, origin + dir * PreviewDraw.px(r, 0.1 + f * 0.7), PreviewDraw.px(r, 0.05))
	PreviewDraw.ball(c, origin, PreviewDraw.px(r, 0.07))
