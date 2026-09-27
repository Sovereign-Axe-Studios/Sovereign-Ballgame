extends GameMod
## Sprinkler -- shots cycle through fixed offsets from the aim line, left to
## right, then repeat: controlled coverage instead of Spread's random wobble.

## Offsets from the aim, degrees, in firing order.
const OFFSETS: Array[float] = [-20.0, 0.0, 20.0]

func _init() -> void:
	category = Category.SHOT_SPREAD
	display_name = "Sprinkler"
	description = "Shots cycle %s° / %s° / %s° around the aim line." % [OFFSETS[0], OFFSETS[1], OFFSETS[2]]

func shot_direction(_rules: GameRules, aim: Vector2, shot_index: int) -> Vector2:
	return aim.rotated(deg_to_rad(OFFSETS[shot_index % OFFSETS.size()]))

## Three fixed lanes fanning from the shooter, a ball running down each in turn.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var origin := PreviewDraw.at(r, 0.5, 0.88)
	var aim := Vector2.UP.rotated(deg_to_rad(8.0))
	for i in range(OFFSETS.size()):
		var dir := aim.rotated(deg_to_rad(OFFSETS[i] * 1.4))
		c.draw_line(origin, origin + dir * PreviewDraw.px(r, 0.8), PreviewDraw.FRAME, 2.0)
	var lane := int(t / 0.45) % OFFSETS.size()
	var f := fposmod(t, 0.45) / 0.45
	var dir := aim.rotated(deg_to_rad(OFFSETS[lane] * 1.4))
	PreviewDraw.ball(c, origin + dir * PreviewDraw.px(r, 0.1 + f * 0.7), PreviewDraw.px(r, 0.055))
	PreviewDraw.ball(c, origin, PreviewDraw.px(r, 0.07))
