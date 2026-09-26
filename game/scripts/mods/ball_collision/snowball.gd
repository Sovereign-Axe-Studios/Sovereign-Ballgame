extends GameMod
## Snowball -- fewer balls, but each one hits harder with every bounce.
## Scales fast in a dense field and slower in a sparse one.

## Ball count is divided by this (rounded up, never below 1).
const BALL_DIVISOR := 3
## Extra damage per bounce the ball has made so far (walls and blocks).
const DAMAGE_PER_BOUNCE := 1
## Visual growth per bounce, and its cap (x the normal radius). Cosmetic: the
## collider doesn't grow, so a snowball still fits the gaps it could before.
const GROWTH_PER_BOUNCE := 0.12
const MAX_DRAW_SCALE := 2.5
## The power label under the ball.
const LABEL_SIZE := 26
const LABEL_COLOR := Color("#f4c0d1")

func _init() -> void:
	category = Category.BALL_COLLISION
	display_name = "Snowball"
	description = "1/%d the balls, but each gains +%d damage per bounce." % [BALL_DIVISOR, DAMAGE_PER_BOUNCE]

func shots_for_round(_rules: GameRules, ball_count: int) -> int:
	return maxi(1, ceili(float(ball_count) / float(BALL_DIVISOR)))

func damage_for(rules: GameRules, ball: Ball) -> int:
	return rules.ball_damage + ball.bounces * DAMAGE_PER_BOUNCE

func ball_draw_scale(_rules: GameRules, ball: Ball) -> float:
	return minf(MAX_DRAW_SCALE, 1.0 + ball.bounces * GROWTH_PER_BOUNCE)

## Its current hit power, just under the ball.
func draw_ball_overlay(rules: GameRules, ball: Ball, radius: float) -> void:
	PreviewDraw.text(ball, Vector2(0.0, radius + LABEL_SIZE * 0.7), str(damage_for(rules, ball)),
		LABEL_SIZE, LABEL_COLOR)

## A ball swelling with every bounce, its damage counting up.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var n := 1 + int(PreviewDraw.phase(t, 3.0) * 6.0)
	var center := PreviewDraw.at(r, 0.5, 0.58)
	var radius := PreviewDraw.px(r, 0.06 + n * 0.018)
	for k in range(n - 1):
		c.draw_arc(center, radius + PreviewDraw.px(r, 0.05 + k * 0.035), -0.7, 0.7, 12, PreviewDraw.FRAME, 2.0)
	PreviewDraw.ball(c, center, radius)
	PreviewDraw.text(c, center - Vector2(0, radius + PreviewDraw.px(r, 0.1)), "+%d" % n,
		int(PreviewDraw.px(r, 0.16)), PreviewDraw.GLOW)
