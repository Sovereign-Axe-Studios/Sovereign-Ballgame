extends GameMod
## Reinforcements -- placeholder. Listed (greyed out) so the Custom screen
## shows the category; no behaviour yet. From the GDD: blocks move every
## other turn, and a row moving into an occupied row adds its value to it.

func _init() -> void:
	category = Category.SPAWN_DIRECTION
	display_name = "Reinforcements"
	description = "Coming soon: rows alternate moving, and merge into occupied rows."
	available = false

## Two rows closing on each other. Static: this mod isn't built yet.
func draw_preview(c: CanvasItem, r: Rect2, _t: float) -> void:
	PreviewDraw.board(c, r)
	var s := PreviewDraw.px(r, 0.2)
	for i in range(3):
		PreviewDraw.block(c, PreviewDraw.at(r, 0.25 + i * 0.25, 0.3), s, 2)
		PreviewDraw.block(c, PreviewDraw.at(r, 0.25 + i * 0.25, 0.7), s, 3)
	PreviewDraw.text(c, PreviewDraw.at(r, 0.5, 0.5), "v  v  v", int(PreviewDraw.px(r, 0.12)), PreviewDraw.FRAME)
