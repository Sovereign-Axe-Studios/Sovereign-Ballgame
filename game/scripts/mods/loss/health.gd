extends GameMod
## Health -- blocks reaching the bottom deal their value as damage instead of
## ending the run outright. Big blocks hurt more than small ones.

const START_HEALTH := 100

## Per-run state (a fresh mod per run, like Lives).
var health: int = START_HEALTH

func _init() -> void:
	category = Category.LOSS
	display_name = "Health"
	description = "%d HP; blocks reaching the bottom hit you for their value." % START_HEALTH
	live_preview = false

func on_death_row_reached(_rules: GameRules, blocks: Array[Block]) -> bool:
	for block in blocks:
		if is_instance_valid(block):
			health -= block.value
			block.hit(block.value)
	return health > 0

func status_text(_rules: GameRules) -> String:
	return "HP %d" % maxi(0, health)

## A health bar taking a chunk as a block lands.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var p := PreviewDraw.phase(t, 3.0)
	var hp := 1.0 - 0.3 * floorf(p * 3.0) / 2.0
	var bar := Rect2(PreviewDraw.at(r, 0.12, 0.62), Vector2(r.size.x * 0.76, PreviewDraw.px(r, 0.12)))
	c.draw_rect(bar, PreviewDraw.FRAME, false, 2.0)
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp, bar.size.y)), Color("#e53935"), true)
	PreviewDraw.text(c, PreviewDraw.at(r, 0.5, 0.45), "HP %d" % roundi(hp * START_HEALTH), int(PreviewDraw.px(r, 0.15)), PreviewDraw.GLOW)
	PreviewDraw.block(c, PreviewDraw.at(r, 0.5, lerpf(0.15, 0.3, fposmod(p * 3.0, 1.0))), PreviewDraw.px(r, 0.16), 15)
