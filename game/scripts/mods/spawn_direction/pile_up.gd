extends GameMod
## Pile-Up (Theo's) -- each column is pushed only by what arrives above it.
## The new row enters at row 0; in a column that got something, the push
## runs down through the touching occupants and stops at the first gap,
## which the last pushed occupant fills. Occupants below a gap stay put, and
## a column that got nothing this round doesn't move at all -- so opening
## gaps slows the whole field down.
##
##   before        new [3] arrives     after
##   r1 [5]                            [3]
##   r2 [4]                            [5]
##   r3 ( )  gap                       [4]
##   r4 [9]                            [9]  not pushed

func _init() -> void:
	category = Category.SPAWN_DIRECTION
	display_name = "Pile-Up"
	description = "New rows only push the blocks touching them; a gap stops the push."
	live_preview = false

func advance_field(rules: GameRules, grid: GridManager, round_number: int) -> bool:
	grid.spawn_row(round_number + 1, 0)
	for col in range(rules.grid_width):
		if grid.occupant(col, 0) == null:
			continue
		# The first gap below the entering occupant; none = the column is full
		# to the bottom, so everything shifts and the bottom falls off.
		var gap := rules.grid_height - 1
		for row in range(1, rules.grid_height):
			if grid.occupant(col, row) == null:
				gap = row
				break
		var bottom := grid.occupant(col, gap)
		if bottom != null:
			grid.cells[gap][col] = null
			bottom.queue_free()
		for row in range(gap, 0, -1):
			grid.move_cell(Vector2i(col, row - 1), Vector2i(col, row))
	grid.clear_pickups_on_death_row()
	return grid.resolve_death_row(grid.blocks_on_death_row())

## One column: the new block pushes the touching pair down into the gap; the
## block below the gap stays.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var p := minf(1.0, PreviewDraw.phase(t, 2.4) * 1.6)
	var s := PreviewDraw.px(r, 0.19)
	var step := 0.19
	PreviewDraw.block(c, PreviewDraw.at(r, 0.5, lerpf(0.05, 0.15, p)), s, 3)
	PreviewDraw.block(c, PreviewDraw.at(r, 0.5, 0.15 + step * p), s, 5)
	PreviewDraw.block(c, PreviewDraw.at(r, 0.5, 0.34 + step * p), s, 4)
	PreviewDraw.block(c, PreviewDraw.at(r, 0.5, 0.72), s, 9)
	if p < 1.0:
		PreviewDraw.text(c, PreviewDraw.at(r, 0.82, 0.53), "gap", int(PreviewDraw.px(r, 0.1)), PreviewDraw.GLOW)
