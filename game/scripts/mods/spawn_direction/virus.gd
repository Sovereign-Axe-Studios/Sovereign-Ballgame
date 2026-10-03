extends GameMod
## Virus -- the field never shifts. Each round the new row's units land in
## random cells of the top two rows (landing on a block adds to it), then
## every block worth MIN_SPLIT_VALUE or more splits: it keeps half and sends
## half to a random neighbour (down weighted higher), where an existing block
## absorbs it. Total value is conserved; you lose when it spreads onto the
## death row.
##
## The field never shifts, so the usual rules would starve the player of
## balls: the spawn rows fill with blocks and leave no room for a pickup, and
## a pickup that did land would be buried by the next landing. So Virus never
## places a block on a pickup (a landing there fizzles; a split there doesn't
## happen), and if the rolled row is full the round's pickup goes in the
## topmost row above the death row that has an empty cell.

const MIN_SPLIT_VALUE := 2
## Relative odds of splitting down vs left / right.
const DOWN_WEIGHT := 2
## The new row's units land somewhere in rows 0..SPAWN_ROWS-1.
const SPAWN_ROWS := 2

func _init() -> void:
	category = Category.SPAWN_DIRECTION
	display_name = "Virus"
	description = "Nothing moves; blocks split and spread instead. Don't let it reach the bottom."
	live_preview = false

func advance_field(rules: GameRules, grid: GridManager, round_number: int) -> bool:
	# Roll where the new units land BEFORE spreading: the spread's draws depend
	# on the board, and the incoming row shouldn't (same seed = same row).
	var rng := rules.field_rng
	var units := maxi(1, rules.row_units(round_number + 1))
	var unit_value := maxi(1, rules.unit_value(round_number + 1))
	var landings: Array[Vector2i] = []
	for i in range(units):
		landings.append(Vector2i(rng.randi_range(0, rules.grid_width - 1), rng.randi_range(0, SPAWN_ROWS - 1)))
	var pickup_row := rng.randi_range(0, SPAWN_ROWS - 1)
	var pickup_roll := grid.roll_pickup()

	_spread(rules, grid)
	for cell in landings:
		if not grid.occupant(cell.x, cell.y) is BallPickup:
			grid.place_block(unit_value, cell.x, cell.y)
	var row := _pickup_row(rules, grid, pickup_row)
	if row >= 0:
		grid.place_pickup(row, pickup_roll)
	return grid.resolve_death_row(grid.blocks_on_death_row())

func _spread(rules: GameRules, grid: GridManager) -> void:
	# Snapshot first: blocks created by this pass don't split until next round.
	var blocks: Array[Block] = []
	for row: Array in grid.cells:
		for item in row:
			if item is Block:
				blocks.append(item as Block)
	var dirs: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0)]
	for i in range(DOWN_WEIGHT):
		dirs.append(Vector2i(0, 1))
	for block in blocks:
		if not is_instance_valid(block) or block.value < MIN_SPLIT_VALUE:
			continue
		var d: Vector2i = dirs[rules.field_rng.randi_range(0, dirs.size() - 1)]
		var target := Vector2i(block.grid_col, block.grid_row) + d
		if not grid.in_bounds(target.x, target.y) or grid.occupant(target.x, target.y) is BallPickup:
			continue
		var half := block.value / 2
		block.value -= half
		block.refresh()
		grid.place_block(half, target.x, target.y)

## The rolled spawn row if it has an empty cell, else the topmost row that has
## one. Never the death row.
## -1 if the whole field above the death row is full.
func _pickup_row(rules: GameRules, grid: GridManager, rolled: int) -> int:
	var rows: Array[int] = [rolled]
	for row in range(rules.death_row()):
		if row != rolled:
			rows.append(row)
	for row in rows:
		for col in range(rules.grid_width):
			if grid.occupant(col, row) == null:
				return row
	return -1

## A block splitting in two, the child creeping downward.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var p := minf(1.0, PreviewDraw.phase(t, 2.4) * 1.6)
	var s := PreviewDraw.px(r, 0.24)
	var parent := PreviewDraw.at(r, 0.5, 0.3)
	PreviewDraw.block(c, parent, s, 8 if p < 0.3 else 4)
	if p >= 0.3:
		var f := (p - 0.3) / 0.7
		PreviewDraw.block(c, parent.lerp(PreviewDraw.at(r, 0.5, 0.6), f), s * (0.6 + 0.4 * f), 4)
