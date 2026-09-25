extends GameMod
## Modified grid -- a custom board size. The layout already sizes cells from
## the grid, so this is value-only.

const WIDTH := 9
## Includes the spawn row (0) and the death row (HEIGHT - 1).
const HEIGHT := 11

func _init() -> void:
	category = Category.GRID
	display_name = "%dx%d Grid" % [WIDTH, HEIGHT]
	description = "A %d wide, %d tall board." % [WIDTH, HEIGHT]
	live_preview = false

func apply(rules: GameRules) -> void:
	rules.grid_width = WIDTH
	rules.grid_height = HEIGHT

## The board's grid lines growing from the stock size to this one.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var f := minf(1.0, PreviewDraw.phase(t, 3.0) * 1.6)
	var cols := roundi(lerpf(7.0, float(WIDTH), f))
	var rows := roundi(lerpf(9.0, float(HEIGHT), f))
	var inner := r.grow(-PreviewDraw.px(r, 0.1))
	for i in range(cols + 1):
		var x := inner.position.x + inner.size.x * i / cols
		c.draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), PreviewDraw.FRAME, 1.0)
	for j in range(rows + 1):
		var y := inner.position.y + inner.size.y * j / rows
		c.draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), PreviewDraw.FRAME, 1.0)
	PreviewDraw.text(c, r.get_center(), "%dx%d" % [cols, rows], int(PreviewDraw.px(r, 0.18)), PreviewDraw.GLOW)
