extends GameMod
## Boss -- one block per row, carrying the whole row's worth at 6x strength.

## Units the single block carries. Each unit is worth the round number, so
## 6 = "6x strength" in the GDD.
const UNITS := 6

func _init() -> void:
	category = Category.DENSITY
	display_name = "Boss"
	description = "One block per row at %dx strength." % UNITS

# No max_units_per_cell change needed: spawn_row raises the cap on its own
# when the row's units can't otherwise fit in the occupied cells.

func row_units(_rules: GameRules, _round_number: int) -> int:
	return UNITS

func open_slots(rules: GameRules) -> int:
	return rules.grid_width - 1
