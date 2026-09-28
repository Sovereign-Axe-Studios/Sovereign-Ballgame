extends Node
## Headless check that seeded runs are deterministic:
##   godot --headless --path . scenes/tools/check_seeds.tscn
## Builds bare GridManagers (no Game, no balls) and drives the field steps
## the way Game does. Exits 1 on any failure.
##
##  1. Same mods + seed -> identical boards for ROUNDS rounds, even with the
##     global RNG churned differently between them (cosmetic randomness
##     must never leak into gameplay).
##  2. Same mods + seed, but one board "played differently" (blocks knocked
##     out, extra field_rng draws) -> the incoming row is still identical.
##     Only for mods on the stock field step (spawn into the empty row 0,
##     shift everything down), where row 1 afterwards IS the fresh row. Virus,
##     Reinforcements and Pile-Up mix the new row into what's already there.
##  3. A different seed -> a different board.
##
## A scene, not a `-s` script: `-s` compiles before autoloads are registered.

const ROUNDS := 30
const SEED := 123456789
const CELL := 100.0

func _ready() -> void:
	var failures: Array[String] = []
	# [label, mods, incoming-row check applies]
	var cases: Array = [
		["stock", [], true],
		["Random Tilt", [Cfg.RandomRotation], true],
		["Triangles + Random Tilt", [Cfg.Triangles, Cfg.RandomRotation], true],
		["Checkers", [Cfg.Checkers], true],
		["Boss", [Cfg.Boss], true],
		["9x11", [Cfg.ModifiedGrid], true],
		["Pile-Up", [Cfg.PileUp], false],
		["Reinforcements", [Cfg.Reinforcements], false],
		["Virus + Random Tilt", [Cfg.Virus, Cfg.RandomRotation], false],
		["Wormholes", [Cfg.Wormholes], true],
	]
	for c: Array in cases:
		var label: String = c[0]
		var scripts: Array = c[1]
		var a := _board(scripts, SEED)
		var b := _board(scripts, SEED)
		var perturbed := _board(scripts, SEED)
		var other := _board(scripts, SEED + 1)
		var same_ok := true
		var row_ok := true
		var differs := false
		for r in range(1, ROUNDS + 1):
			# Cosmetic noise between rounds, different amounts per board.
			for i in range(r % 7):
				randf()
			_step(a, r)
			for i in range(r * 3):
				randi()
			_step(b, r)
			if same_ok and _snapshot(a) != _snapshot(b):
				failures.append("%s: same seed diverged at round %d" % [label, r])
				same_ok = false
			if c[2]:
				_knock_out(perturbed, r)
				_step(perturbed, r)
				var incoming := _incoming_row(a)
				if row_ok and _row_snapshot(a, incoming) != _row_snapshot(perturbed, incoming):
					failures.append("%s: incoming row differs after other play, round %d" % [label, r])
					row_ok = false
			_step(other, r)
			if _snapshot(a) != _snapshot(other):
				differs = true
		if not differs:
			failures.append("%s: seeds %d and %d built identical boards" % [label, SEED, SEED + 1])
		var status := "ok  " if same_ok and row_ok and differs else "FAIL"
		print("  %s  %-26s %d rounds%s" % [status, label, ROUNDS,
			"" if c[2] else "  (same-seed only)"])
		for board in [a, b, perturbed, other]:
			(board.grid as GridManager).queue_free()

	for f in failures:
		printerr("FAIL: " + f)
	print("%d cases, %d failures" % [cases.size(), failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)

## A bare board with `scripts` installed, primed the way Game._prime_board does.
func _board(scripts: Array, run_seed: int) -> Dictionary:
	var rules := GameRules.new()
	rules.run_seed = run_seed
	# Straight into the slots, like check_mods calls hooks directly: locked
	# mods (Wormholes) get tested without touching the player's unlocks.
	for script: GDScript in scripts:
		var mod := script.new() as GameMod
		rules._slots[mod.category] = mod
	for mod in rules.active_mods():
		mod.apply(rules)
	rules.play_left = 0.0
	rules.play_right = CELL * rules.grid_width
	var grid := GridManager.new()
	add_child(grid)
	grid.configure(rules, CELL, Vector2.ZERO)
	var effects := Node2D.new()
	grid.add_child(effects)
	var field := Playfield.new()
	field.rules = rules
	field.grid = grid
	field.effects_root = effects
	rules.seed_field(1)
	grid.spawn_row(1)
	grid.advance()
	rules.on_run_start(field)
	return {"rules": rules, "grid": grid, "field": field}

## One end-of-round field step, as Game._end_round does it. A loss is
## ignored: the check is about what spawns, not about surviving.
func _step(board: Dictionary, round_number: int) -> void:
	var rules: GameRules = board.rules
	rules.advance_field(board.grid, round_number)
	rules.on_round_end(board.field)

## "Play differently": clear a few cells and burn some field_rng draws.
## Uses its own RNG so the global stream stays out of it.
func _knock_out(board: Dictionary, round_number: int) -> void:
	var grid: GridManager = board.grid
	var rng := RandomNumberGenerator.new()
	rng.seed = round_number
	for i in range(3):
		var col := rng.randi_range(0, grid.rules.grid_width - 1)
		var row := rng.randi_range(1, grid.rules.grid_height - 1)
		var n = grid.cells[row][col]
		if is_instance_valid(n):
			n.free()
		grid.cells[row][col] = null
	for i in range(rng.randi_range(1, 20)):
		(board.rules as GameRules).field_rng.randf()

## Where the stock field step leaves the fresh row: one below the spawn row.
func _incoming_row(board: Dictionary) -> int:
	return (board.grid as GridManager).rules.spawn_row_index + 1

func _snapshot(board: Dictionary) -> String:
	var grid: GridManager = board.grid
	var parts: PackedStringArray = []
	for row in range(grid.cells.size()):
		parts.append(_row_snapshot(board, row))
	return "\n".join(parts)

func _row_snapshot(board: Dictionary, row: int) -> String:
	var grid: GridManager = board.grid
	var parts: PackedStringArray = []
	for item in grid.cells[row]:
		if item is Block:
			var block := item as Block
			parts.append("B%d/%s/%.3f" % [block.value, block._shape_kind, block.rotation_degrees])
		elif item is BallPickup:
			parts.append("P")
		else:
			parts.append(".")
	return " ".join(parts)
