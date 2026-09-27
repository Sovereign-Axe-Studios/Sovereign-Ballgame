extends GameMod
## Checkers -- blocks only go in alternating columns, switching sides each
## row, so the field stacks up in a checkerboard with a lane between every
## pair of blocks.

func _init() -> void:
	category = Category.DENSITY
	display_name = "Checkers"
	description = "Blocks spawn one gap apart, alternating each row -- a checkerboard."

func choose_columns(_rules: GameRules, width: int, _count: int, round_number: int) -> Array[int]:
	var out: Array[int] = []
	for c in range(width):
		if c % 2 == round_number % 2:
			out.append(c)
	return out

## A checkerboard filling in row by row.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var rows := 1 + int(PreviewDraw.phase(t, 3.0) * 4.0)
	var s := PreviewDraw.px(r, 0.17)
	for row in range(rows):
		for col in range(5):
			if col % 2 == row % 2:
				PreviewDraw.block(c, PreviewDraw.at(r, 0.1 + col * 0.2, 0.15 + row * 0.2), s, 2 + row)
