class_name CuratedModes
## The hand-picked modes on the Mode Select list. Each is {name, description,
## mods: Array[GDScript]}, at most one mod per category. A mode that uses a
## locked mod shows as ??? until it's unlocked. A function, not a const,
## because `Cfg` is an autoload and not a const expression.

static func all() -> Array[Dictionary]:
	return [
		_mode("Boss Rush", "One giant block every row. Three lives to get through them.",
			[Cfg.Boss, Cfg.Lives]),
		_mode("Tilt", "Wobbly shots, tilted blocks, and walls that loop around.",
			[Cfg.Spread, Cfg.Rotated, Cfg.WrapAround]),
		_mode("Plague", "The field spreads on its own. Poison it, and outlast it.",
			[Cfg.Poison, Cfg.Virus, Cfg.Health]),
		_mode("Pinball", "Round bumpers, fanned shots, and fewer balls that hit harder every bounce.",
			[Cfg.Circles, Cfg.Sprinkler, Cfg.Snowball]),
		_mode("Laser Grid", "Balls cut straight through a checkerboard -- until they burn out.",
			[Cfg.BouncePierce, Cfg.Checkers]),
		_mode("Avalanche", "Rows march in waves and merge. Build enough power to break them.",
			[Cfg.Reinforcements, Cfg.Snowball, Cfg.Health]),
		_mode("Kaleidoscope", "Triangles at every angle. No two bounces alike.",
			[Cfg.Triangles, Cfg.RandomRotation, Cfg.Spread]),
		_mode("Traffic Jam", "Rows only push what they touch. Keep the gaps open.",
			[Cfg.PileUp, Cfg.Triangles, Cfg.Lives]),
		_mode("Marathon", "A big board and spare lives. Pace yourself.",
			[Cfg.ModifiedGrid, Cfg.Sprinkler, Cfg.Lives]),
		_mode("Pocket Arena", "A tiny board, heavy hitters, and a health bar.",
			[Cfg.CompactGrid, Cfg.Snowball, Cfg.Health]),
		_mode("Hearthian", "Twenty-two seconds, a pair of wormholes, and a sky full of round worlds.",
			[Cfg.Wormholes, Cfg.TimeRewind, Cfg.Circles]),
	]

## True if every mod in `mode` can be picked right now.
static func is_unlocked(mode: Dictionary) -> bool:
	for script: GDScript in mode.mods:
		if not (script.new() as GameMod).is_selectable():
			return false
	return true

static func _mode(mode_name: String, description: String, scripts: Array) -> Dictionary:
	var mods: Array[GDScript] = []
	mods.assign(scripts)
	return {"name": mode_name, "description": description, "mods": mods}
