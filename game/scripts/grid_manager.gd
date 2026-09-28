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

func _ready() -> void:
	Settings.changed.connect(queue_redraw)

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
func spawn_row(round_number: int, row: int = -1) -> void:
	if row < 0:
		row = rules.spawn_row_index
	var w := rules.grid_width
	var units := maxi(1, rules.row_units(round_number))
	var unit_value := maxi(1, rules.unit_value(round_number))

	# Occupied columns = width minus the gaps this row leaves open.
	var count := clampi(w - rules.open_slots(), 1, mini(w - 1, units))

	# A DENSITY mod may pick a different number of columns (Checkers).
	var columns := rules.choose_columns(w, count, round_number)
	count = columns.size()
	if count == 0:
		return

	# Units that may stack on one cell, raised if the row could not fit otherwise.
	var cap := rules.max_units_per_cell
	if cap <= 0:
		cap = units
	cap = maxi(cap, ceili(float(units) / float(count)))

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
		var pick := rules.field_rng.randi_range(0, open.size() - 1)
		var idx: int = open[pick]
		stacks[idx] += 1
		remaining -= 1
		if stacks[idx] >= cap:
			open.remove_at(pick)

	# Rolled BEFORE placing: configure_block may draw from field_rng too
	# (Random Tilt), and the pickup shouldn't shift with how many blocks got
	# a fresh cell versus merged into an old one.
	var pickup_roll := roll_pickup()

	for i in range(count):
		place_block(stacks[i] * unit_value, columns[i], row)

	place_pickup(row, pickup_roll)

## Put a new block at (col, row), or add `value` to the block already there.
func place_block(value: int, col: int, row: int) -> Block:
	var existing = cells[row][col]
	if existing is Block:
		merge_into(existing as Block, value)
		return existing
	if is_instance_valid(existing):
		existing.queue_free()   # a pickup under a new block just leaves play
	var block: Block = BlockScene.instantiate()
	add_child(block)
	block.position = cell_center(col, row)
	block.setup(value, cell_size, col, row)
	rules.configure_block(block)
	block.destroyed.connect(_on_block_destroyed)
	cells[row][col] = block
	return block

## Maybe drop a +1 ball pickup into an empty cell of `row` (pickup_chance).
func maybe_place_pickup(row: int) -> void:
	place_pickup(row, roll_pickup())

## The field_rng draws a pickup needs, taken up front: [chance roll, column
## pick in 0..1]. Always two draws, so the stream stays in step either way.
func roll_pickup() -> Vector2:
	return Vector2(rules.field_rng.randf(), rules.field_rng.randf())

## Place a pickup from a roll_pickup() result, if the chance hit and `row`
## has an empty cell.
func place_pickup(row: int, roll: Vector2) -> void:
	if roll.x > rules.pickup_chance:
		return
	var empty: Array[int] = []
	for col in range(rules.grid_width):
		if cells[row][col] == null:
			empty.append(col)
	if empty.is_empty():
		return
	var col: int = empty[mini(int(roll.y * empty.size()), empty.size() - 1)]
	var pickup: BallPickup = PickupScene.instantiate()
	add_child(pickup)
	pickup.position = cell_center(col, row)
	pickup.setup(cell_size, col, row)
	pickup.collected.connect(_on_pickup_collected)
	cells[row][col] = pickup


# ------------------------------------------------------------------ shifting

## Add `value` to `block` (spawning onto it, or a moving block merging in).
func merge_into(block: Block, value: int) -> void:
	block.value += value
	block.start_value = maxi(block.start_value, block.value)
	block.refresh()

## What's at (col, row): a Block, a BallPickup, or null (also off the grid).
func occupant(col: int, row: int) -> Node2D:
	if not in_bounds(col, row):
		return null
	var n = cells[row][col]
	return n if is_instance_valid(n) else null

## Move whatever is at `from` into the EMPTY cell `to`, sliding it there.
func move_cell(from: Vector2i, to: Vector2i) -> void:
	var n = cells[from.y][from.x]
	cells[from.y][from.x] = null
	if not is_instance_valid(n):
		return
	cells[to.y][to.x] = n
	n.grid_row = to.y
	if "grid_col" in n:
		n.grid_col = to.x
	_slide(n, to.x, to.y)

## A missed pickup on the death row just leaves play (field-step mods call
## this; the stock advance() does it inline).
func clear_pickups_on_death_row() -> void:
	var row := rules.death_row()
	for col in range(rules.grid_width):
		var n := occupant(col, row)
		if n is BallPickup:
			cells[row][col] = null
			n.queue_free()

## Every Block at or past the death row.
func blocks_on_death_row() -> Array[Block]:
	var out: Array[Block] = []
	for row in range(maxi(0, rules.death_row()), rules.grid_height):
		for item in cells[row]:
			if item is Block:
				out.append(item as Block)
	return out

## The one loss check every field step ends with: Debug.invincible destroys
## the blocks and carries on; otherwise the LOSS mod decides. True = lost.
func resolve_death_row(reached: Array[Block]) -> bool:
	if reached.is_empty():
		return false
	if Debug.invincible:
		# Through the normal Block.hit path, so fragments/signals still fire.
		for block in reached:
			block.hit(block.value)
		return false
	return not rules.on_death_row_reached(reached)

## Move everything down one row. Returns true if the run is lost: a Block
## ended up in the death row and neither Debug.invincible nor the LOSS mod
## (`rules.on_death_row_reached`) absorbed it.
func advance() -> bool:
	var h := rules.grid_height
	var w := rules.grid_width
	var death := rules.death_row()
	var reached: Array[Block] = []

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
				reached.append(n as Block)

	return resolve_death_row(reached)

## Debug helper: pull the field back up one row.
func shift_up() -> void:
	# Row 0 is about to be overwritten by row 1's occupant below. Under the
	# normal round loop it is always empty by the time this runs, but a
	# second consecutive shift_up (debug holding Shift+Up) would otherwise
	# silently orphan whatever this call just moved into it -- free it first.
	for col in range(rules.grid_width):
		var stale = cells[0][col]
		if is_instance_valid(stale):
			stale.queue_free()
		cells[0][col] = null

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


# --------------------------------------------------------------- debug tools

## Destroys every Block in `row`, through `Block.hit()` so the usual
## destroyed signal / cell cleanup still runs. Debug-only: a real ball never
## clears more than the one block it hits.
func clear_row(row: int) -> void:
	if not in_bounds(0, row):
		return
	for col in range(rules.grid_width):
		var occ = cells[row][col]
		if occ is Block:
			occ.hit(occ.value)

func clear_all() -> void:
	for row in range(rules.grid_height):
		clear_row(row)

## World point -> cell, or (-1, -1) if it lands outside the grid.
func cell_at(point: Vector2) -> Vector2i:
	var local := point - origin
	var col := int(floor(local.x / cell_size))
	var row := int(floor(local.y / cell_size))
	if in_bounds(col, row):
		return Vector2i(col, row)
	return Vector2i(-1, -1)

## The Block at a world point, or null if there is none there.
func block_at(point: Vector2) -> Block:
	var c := cell_at(point)
	if c.x < 0:
		return null
	var occ = cells[c.y][c.x]
	return occ as Block


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

	# One line per cell edge -- 1x1 against the actual gameplay grid, not a
	# decorative pattern at its own scale. Settings-gated; the death-row
	# tint below is a gameplay indicator, not decoration, so it always shows.
	#
	# Positions are rounded to the nearest pixel: an axis-aligned 1px line at
	# a fractional pixel offset anti-aliases across two rows/columns at half
	# opacity each, which at this alpha reads as "the line is missing" --
	# some rows had exactly that problem before this rounding existed.
	if Settings.show_background_grid:
		var faint := Color(1, 1, 1, 0.045)
		var lw := Settings.grid_line_thickness
		for c in range(rules.grid_width + 1):
			var x := roundf(origin.x + float(c) * cell_size)
			draw_line(Vector2(x, origin.y), Vector2(x, origin.y + h), faint, lw)
		for r in range(rules.grid_height + 1):
			var y := roundf(origin.y + float(r) * cell_size)
			draw_line(Vector2(origin.x, y), Vector2(origin.x + w, y), faint, lw)

	# The row that ends the run.
	var dy := float(rules.death_row()) * cell_size
	draw_rect(Rect2(origin + Vector2(0, dy), Vector2(w, cell_size)), Color(0.9, 0.24, 0.22, 0.10), true)
	draw_line(origin + Vector2(0, dy), origin + Vector2(w, dy), Color(0.9, 0.24, 0.22, 0.55), 3.0)
