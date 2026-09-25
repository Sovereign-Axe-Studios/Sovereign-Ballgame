extends GameMod
## Reinforcements -- placeholder. Listed (greyed out) so the Custom screen
## shows the category; no behaviour yet. From the GDD: blocks move every
## other turn, and a row moving into an occupied row adds its value to it.

func _init() -> void:
	category = Category.SPAWN_DIRECTION
	display_name = "Reinforcements"
	description = "Coming soon: rows alternate moving, and merge into occupied rows."
	available = false
