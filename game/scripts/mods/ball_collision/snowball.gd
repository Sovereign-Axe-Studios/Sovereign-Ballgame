extends GameMod
## Snowball -- fewer balls, but each one hits harder with every bounce.
## Scales fast in a dense field and slower in a sparse one.

## Ball count is divided by this (rounded up, never below 1).
const BALL_DIVISOR := 3
## Extra damage per bounce the ball has made so far (walls and blocks).
const DAMAGE_PER_BOUNCE := 1

func _init() -> void:
	category = Category.BALL_COLLISION
	display_name = "Snowball"
	description = "1/%d the balls, but each gains +%d damage per bounce." % [BALL_DIVISOR, DAMAGE_PER_BOUNCE]

func shots_for_round(_rules: GameRules, ball_count: int) -> int:
	return maxi(1, ceili(float(ball_count) / float(BALL_DIVISOR)))

func damage_for(rules: GameRules, ball: Ball) -> int:
	return rules.ball_damage + ball.bounces * DAMAGE_PER_BOUNCE
