extends GameMod
## Reinforcements -- rows take turns moving: on even rounds the even-indexed
## rows step down one, on odd rounds the odd ones. A block stepping into an
## occupied cell merges into it (values add). The new row arrives in row 0
## every round, merging onto anything still there.

func _init() -> void:
	category = Category.SPAWN_DIRECTION
	display_name = "Reinforcements"
	description = "Rows alternate moving; a row moving into an occupied row merges into it."
	# Rows never move on the preview board.
	live_preview = false

func advance_field(rules: GameRules, grid: GridManager, round_number: int) -> bool:
	var parity := round_number % 2
	# Bottom-up, so a block moves into a cell that has already settled.
	for row in range(rules.grid_height - 2, -1, -1):
		if row % 2 != parity:
			continue
		for col in range(rules.grid_width):
			var mover := grid.occupant(col, row)
			if mover == null:
				continue
			var below := grid.occupant(col, row + 1)
			if below is Block and mover is Block:
				grid.merge_into(below as Block, (mover as Block).value)
				grid.cells[row][col] = null
				mover.queue_free()
			elif below == null:
				grid.move_cell(Vector2i(col, row), Vector2i(col, row + 1))
			elif below is BallPickup and mover is Block:
				grid.cells[row + 1][col] = null
				below.queue_free()
				grid.move_cell(Vector2i(col, row), Vector2i(col, row + 1))
	grid.clear_pickups_on_death_row()
	grid.spawn_row(round_number + 1, 0)
	return grid.resolve_death_row(grid.blocks_on_death_row())

## Two rows: the top one steps down and merges into the one below.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var p := minf(1.0, PreviewDraw.phase(t, 2.4) * 1.6)
	var s := PreviewDraw.px(r, 0.22)
	for i in range(3):
		var u := 0.22 + i * 0.28
		var merged := p >= 1.0
		PreviewDraw.block(c, PreviewDraw.at(r, u, 0.62), s, 5 if merged else 3)
		if not merged:
			PreviewDraw.block(c, PreviewDraw.at(r, u, lerpf(0.34, 0.6, p)), s, 2)
