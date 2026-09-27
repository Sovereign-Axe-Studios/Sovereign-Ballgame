extends GameMod
## Virus -- the field never shifts. Each round the new row's units land in
## random cells of the top two rows (landing on a block adds to it), then
## every block worth MIN_SPLIT_VALUE or more splits: it keeps half and sends
## half to a random neighbour (down weighted higher), where an existing block
## absorbs it. Total value is conserved; you lose when it spreads onto the
## death row.

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
	_spread(rules, grid)
	var units := maxi(1, rules.row_units(round_number + 1))
	var unit_value := maxi(1, rules.unit_value(round_number + 1))
	for i in range(units):
		grid.place_block(unit_value, randi_range(0, rules.grid_width - 1), randi_range(0, SPAWN_ROWS - 1))
	grid.maybe_place_pickup(randi_range(0, SPAWN_ROWS - 1))
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
		var d: Vector2i = dirs[randi_range(0, dirs.size() - 1)]
		var target := Vector2i(block.grid_col, block.grid_row) + d
		if not grid.in_bounds(target.x, target.y):
			continue
		var half := block.value / 2
		block.value -= half
		block.refresh()
		grid.place_block(half, target.x, target.y)

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
