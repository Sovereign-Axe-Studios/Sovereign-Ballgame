class_name CuratedModes
## The hand-picked modes on the Mode Select list. Placeholders for now, but
## playable. Each is {name, description, mods: Array[GDScript]}. A function,
## not a const, because `Cfg` is an autoload and not a const expression.

static func all() -> Array[Dictionary]:
	return [
		{
			"name": "Boss Rush",
			"description": "Placeholder: one huge block per row, three lives.",
			"mods": _mods([Cfg.Boss, Cfg.Lives]),
		},
		{
			"name": "Tilt",
			"description": "Placeholder: wobbly shots, tilted blocks, wrapping walls.",
			"mods": _mods([Cfg.Spread, Cfg.Rotated, Cfg.WrapAround]),
		},
	]

static func _mods(scripts: Array) -> Array[GDScript]:
	var out: Array[GDScript] = []
	out.assign(scripts)
	return out
