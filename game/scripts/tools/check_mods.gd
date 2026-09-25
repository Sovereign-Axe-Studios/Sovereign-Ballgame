extends Node
## Headless smoke check for the mod registry:
##   godot --headless --path . scenes/tools/check_mods.tscn
## Instantiates every mod in Cfg.MODS, checks each category has at most one
## mod-per-file and a display name, installs each available one on a fresh
## GameRules, and calls the value hooks once. Exits 1 on any failure.
##
## A scene, not a `-s` script: `-s` compiles before autoloads are registered,
## so anything touching Ball/Block (which read `Skins`) fails to compile.

func _ready() -> void:
	var failures: Array[String] = []
	var seen: Dictionary = {}
	for script: GDScript in Cfg.MODS:
		var mod := script.new() as GameMod
		var path := script.resource_path
		if mod == null:
			failures.append("%s does not extend GameMod" % path)
			continue
		if mod.display_name == "" or mod.display_name == "None":
			failures.append("%s has no display_name" % path)
		if seen.has(path):
			failures.append("%s is listed twice in Cfg.MODS" % path)
		seen[path] = true
		if not mod.available:
			print("  skip  %-22s %s (unavailable)" % [GameMod.category_name(mod.category), mod.display_name])
			continue
		var rules := GameRules.new()
		var mods: Array[GameMod] = [mod]
		rules.install(mods)
		var units := rules.row_units(5)
		var shots := rules.shots_for_round(9)
		var slots := rules.open_slots()
		if units < 1 or shots < 1 or slots < 1 or slots >= rules.grid_width:
			failures.append("%s: bad hook values units=%d shots=%d open=%d" % [path, units, shots, slots])
		print("  ok    %-22s %s  (units %d, shots %d, open %d, death row %d)" % [
			GameMod.category_name(mod.category), mod.display_name, units, shots, slots, rules.death_row()])

	for f in failures:
		printerr("FAIL: " + f)
	print("%d mods, %d failures" % [Cfg.MODS.size(), failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
