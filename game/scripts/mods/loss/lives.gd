extends GameMod
## Lives -- a row reaching the end zone costs a life instead of the run. The
## run ends when the last life goes.

const START_LIVES := 3

## Per-run state. Run stores mod scripts, not instances, so every run
## (including an R restart) gets a fresh mod and a full set of lives.
var lives_left: int = START_LIVES

func _init() -> void:
	category = Category.LOSS
	display_name = "Lives"
	description = "%d lives; a row reaching the bottom costs one." % START_LIVES
	live_preview = false

## One life per shift, however many blocks landed together -- the GDD's "a
## row reaching the end zone".
func on_death_row_reached(_rules: GameRules, blocks: Array[Block]) -> bool:
	lives_left -= 1
	for block in blocks:
		if is_instance_valid(block):
			block.hit(block.value)
	return lives_left > 0

func status_text(_rules: GameRules) -> String:
	return "LIVES %d" % maxi(0, lives_left)

## Hearts ticking down one per cycle.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var lost := int(PreviewDraw.phase(t, 4.0) * 4.0)
	for i in range(START_LIVES):
		var alive := i < START_LIVES - lost
		_heart(c, PreviewDraw.at(r, 0.25 + i * 0.25, 0.5), PreviewDraw.px(r, 0.1),
			PreviewDraw.GLOW if alive else PreviewDraw.FRAME)

func _heart(c: CanvasItem, center: Vector2, s: float, color: Color) -> void:
	c.draw_circle(center + Vector2(-s * 0.5, -s * 0.2), s * 0.55, color)
	c.draw_circle(center + Vector2(s * 0.5, -s * 0.2), s * 0.55, color)
	c.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-s * 1.02, 0.0), center + Vector2(s * 1.02, 0.0), center + Vector2(0.0, s * 1.2),
	]), color)
