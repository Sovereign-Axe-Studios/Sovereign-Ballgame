extends Node
## Headless smoke check for the mod registry:
##   godot --headless --path . scenes/tools/check_mods.tscn
## Instantiates every mod in Cfg.MODS, checks each has a display name and is
## listed once, calls its value hooks on a fresh GameRules, and draws its
## tile icon at t = 0 and 1.5. Exits 1 on any failure.
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
		# Hooks are called on the mod directly, not through install(), so
		# locked mods get checked too without touching the player's unlocks.
		var rules := GameRules.new()
		mod.apply(rules)
		var units := mod.row_units(rules, 5)
		var shots := mod.shots_for_round(rules, 9)
		var slots := mod.open_slots(rules)
		if units < 1 or shots < 1 or slots < 1 or slots >= rules.grid_width:
			failures.append("%s: bad hook values units=%d shots=%d open=%d" % [path, units, shots, slots])
		# Draw the tile icon at rest and mid-animation. A broken sketch shows
		# up as a SCRIPT ERROR above this mod's line.
		var icon := ModPreviewIcon.new(mod)
		icon.size = Vector2(120, 120)
		add_child(icon)
		for t in [0.0, 1.5]:
			icon._t = t
			icon.queue_redraw()
			await get_tree().process_frame
		icon.queue_free()
		var lock := "" if mod.locked_by == &"" else "  [locked by %s]" % mod.locked_by
		print("  ok    %-22s %s  (units %d, shots %d, open %d, death row %d)%s" % [
			GameMod.category_name(mod.category), mod.display_name, units, shots, slots,
			mod.death_row(rules), lock])

	for f in failures:
		printerr("FAIL: " + f)
	print("%d mods, %d failures" % [Cfg.MODS.size(), failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
