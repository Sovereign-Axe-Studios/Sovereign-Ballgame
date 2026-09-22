class_name GridManager
extends Node2D
## Owns the block lattice: what is in which cell, spawning a new row, and
## shifting everything down a row at the end of a round.
##
## `cells[row][col]` holds a Block, a BallPickup, or null. Row 0 is the spawn
## row at the top; `rules.death_row()` is the row that ends the run.

signal pickup_collected(pickup: BallPickup)
signal block_destroyed(block: Block)

const BlockScene := preload("res://scenes/block.tscn")
const PickupScene := preload("res://scenes/pickup.tscn")

var rules: GameRules
var cell_size: float = 100.0
var origin := Vector2.ZERO          ## top-left corner of cell (0, 0)
var cells: Array = []

func configure(r: GameRules, cell: float, org: Vector2) -> void:
	rules = r
	cell_size = cell
	origin = org
	reset()

func reset() -> void:
	for row: Array in cells:
		for n in row:
			if is_instance_valid(n):
				n.queue_free()
	cells = []
	for _row in range(rules.grid_height):
		var line: Array = []
		line.resize(rules.grid_width)   # fills with null
		cells.append(line)
	queue_redraw()

func cell_center(col: int, row: int) -> Vector2:
	return origin + Vector2((float(col) + 0.5) * cell_size, (float(row) + 0.5) * cell_size)

func in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < rules.grid_width and row >= 0 and row < rules.grid_height

func block_count() -> int:
	var n := 0
	for row: Array in cells:
		for item in row:
			if item is Block:
				n += 1
	return n


# ------------------------------------------------------------------ spawning

## Fill row 0 for `round_number`. The row spends `row_units()` units, each
## worth `unit_value()` (the round number), so every block is a multiple of
## the round. Density mods override those hooks rather than this function.
func spawn_row(round_number: int) -> void:
	var w := rules.grid_width
	var units := maxi(1, rules.row_units(round_number))
	var unit_value := maxi(1, rules.unit_value(round_number))

	# Occupied columns = width minus the gaps this row leaves open.
	var count := clampi(w - rules.open_slots(), 1, mini(w - 1, units))

	# Units that may stack on one cell, raised if the row could not fit otherwise.
	var cap := rules.max_units_per_cell
	if cap <= 0:
		cap = units
	cap = maxi(cap, ceili(float(units) / float(count)))

	var columns: Array[int] = []
	for c in range(w):
		columns.append(c)
	columns.shuffle()
	columns.resize(count)

	# One unit each, then scatter the rest a unit at a time so the row comes out
	# lumpy rather than evenly divided.
	var stacks: Array[int] = []
	stacks.resize(count)
	stacks.fill(1)
	var remaining := units - count
	var open: Array[int] = []
	for i in range(count):
		open.append(i)
	while remaining > 0 and not open.is_empty():
		var pick := randi_range(0, open.size() - 1)
		var idx: int = open[pick]
		stacks[idx] += 1
		remaining -= 1
		if stacks[idx] >= cap:
			open.remove_at(pick)

	for i in range(count):
		_place_block(stacks[i] * unit_value, columns[i], 0)

	_maybe_place_pickup()

func _place_block(value: int, col: int, row: int) -> Block:
	var block: Block = BlockScene.instantiate()
	add_child(block)
	block.position = cell_center(col, row)
	block.setup(value, cell_size, col, row)
	block.destroyed.connect(_on_block_destroyed)
	cells[row][col] = block
	return block

func _maybe_place_pickup() -> void:
	if randf() > rules.pickup_chance:
		return
	var empty: Array[int] = []
	for col in range(rules.grid_width):
		if cells[0][col] == null:
			empty.append(col)
	if empty.is_empty():
		return
	var col: int = empty[randi_range(0, empty.size() - 1)]
	var pickup: BallPickup = PickupScene.instantiate()
	add_child(pickup)
	pickup.position = cell_center(col, 0)
	pickup.setup(cell_size, col, 0)
	pickup.collected.connect(_on_pickup_collected)
	cells[0][col] = pickup


# ------------------------------------------------------------------ shifting

## Move everything down one row. Returns true if a Block ended up in the death
## row, which is the loss condition.
func advance() -> bool:
	var h := rules.grid_height
	var w := rules.grid_width
	var death := rules.death_row()
	var lost := false

	# The death row should already be empty (we lose the instant anything lands
	# there). Belt and braces in case a mod changes death_row_override.
	for col in range(w):
		var stale = cells[h - 1][col]
		if is_instance_valid(stale):
			stale.queue_free()
		cells[h - 1][col] = null

	for row in range(h - 1, 0, -1):
		for col in range(w):
			var n = cells[row - 1][col]
			cells[row - 1][col] = null
			if not is_instance_valid(n):
				continue
			if row >= death and n is BallPickup:
				n.queue_free()          # a missed pickup just leaves play
				continue
			cells[row][col] = n
			n.grid_row = row
			_slide(n, col, row)
			if row >= death and n is Block:
				lost = true
	return lost

## Debug helper: pull the field back up one row.
func shift_up() -> void:
	for row in range(1, rules.grid_height):
		for col in range(rules.grid_width):
			var n = cells[row][col]
			cells[row][col] = null
			if not is_instance_valid(n):
				continue
			if row - 1 < 0:
				n.queue_free()
				continue
			cells[row - 1][col] = n
			n.grid_row = row - 1
			_slide(n, col, row - 1)

func _slide(node: Node2D, col: int, row: int) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "position", cell_center(col, row), 0.22)


# ------------------------------------------------------------------- signals

func _on_block_destroyed(block: Block) -> void:
	if in_bounds(block.grid_col, block.grid_row) and cells[block.grid_row][block.grid_col] == block:
		cells[block.grid_row][block.grid_col] = null
	block_destroyed.emit(block)

func _on_pickup_collected(pickup: BallPickup) -> void:
	if in_bounds(pickup.grid_col, pickup.grid_row) and cells[pickup.grid_row][pickup.grid_col] == pickup:
		cells[pickup.grid_row][pickup.grid_col] = null
	pickup_collected.emit(pickup)


# --------------------------------------------------------------- grid guides

func _draw() -> void:
	if rules == null:
		return
	var w := float(rules.grid_width) * cell_size
	var h := float(rules.grid_height) * cell_size
	var faint := Color(1, 1, 1, 0.045)
	for c in range(rules.grid_width + 1):
		var x := float(c) * cell_size
		draw_line(origin + Vector2(x, 0), origin + Vector2(x, h), faint, 1.0)
	for r in range(rules.grid_height + 1):
		var y := float(r) * cell_size
		draw_line(origin + Vector2(0, y), origin + Vector2(w, y), faint, 1.0)
	# The row that ends the run.
	var dy := float(rules.death_row()) * cell_size
	draw_rect(Rect2(origin + Vector2(0, dy), Vector2(w, cell_size)), Color(0.9, 0.24, 0.22, 0.10), true)
	draw_line(origin + Vector2(0, dy), origin + Vector2(w, dy), Color(0.9, 0.24, 0.22, 0.55), 3.0)
