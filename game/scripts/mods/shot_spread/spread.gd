extends GameMod
## Spread -- each shot leaves at the aim angle plus a random wobble.
## Value-only: the wobble itself is already built into Game._spawn_ball via
## `GameRules.random_rotate_value_deg`; this mod just turns it up.

## Max wobble either side of the aim line, in degrees.
const SPREAD_DEGREES := 6.0

func _init() -> void:
	category = Category.SHOT_SPREAD
	display_name = "Spread"
	description = "Each shot fires at the aim angle ±%s° of random variation." % SPREAD_DEGREES

func apply(rules: GameRules) -> void:
	rules.random_rotate_value_deg = SPREAD_DEGREES
