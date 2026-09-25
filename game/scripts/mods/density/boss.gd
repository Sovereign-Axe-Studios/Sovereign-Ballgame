extends GameMod
## Boss -- one block per row, carrying the whole row's worth at 6x strength.

## Units the single block carries. Each unit is worth the round number, so
## 6 = "6x strength" in the GDD.
const UNITS := 6

func _init() -> void:
	category = Category.DENSITY
	display_name = "Boss"
	description = "One block per row at %dx strength." % UNITS

# No max_units_per_cell change needed: spawn_row raises the cap on its own
# when the row's units can't otherwise fit in the occupied cells.

func row_units(_rules: GameRules, _round_number: int) -> int:
	return UNITS

func open_slots(rules: GameRules) -> int:
	return rules.grid_width - 1

## One big block in an otherwise empty row, pulsing.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	for i in range(5):
		var cell := PreviewDraw.at(r, 0.1 + i * 0.2, 0.4)
		var s := PreviewDraw.px(r, 0.16)
		c.draw_rect(Rect2(cell - Vector2.ONE * s * 0.5, Vector2.ONE * s), PreviewDraw.FRAME, false, 1.0)
	var pulse := 1.0 + 0.06 * sin(t * 4.0)
	PreviewDraw.block(c, PreviewDraw.at(r, 0.5, 0.4), PreviewDraw.px(r, 0.3) * pulse, UNITS)
	PreviewDraw.text(c, PreviewDraw.at(r, 0.5, 0.78), "%dx" % UNITS, int(PreviewDraw.px(r, 0.16)), PreviewDraw.GLOW)
