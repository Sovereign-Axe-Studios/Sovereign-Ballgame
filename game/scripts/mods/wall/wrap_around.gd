extends GameMod
## Wrap Around -- a ball touching a side wall reappears at the other side,
## still travelling the same way. The ceiling still bounces.

## A contact counts as a side wall when |normal.x| is above this. Stops a
## ceiling-corner graze from wrapping.
const SIDE_NORMAL_THRESHOLD := 0.5
## Pixels the wrapped ball is nudged away from the far wall, so its next
## substep doesn't start touching it.
const EXIT_NUDGE := 1.0

func _init() -> void:
	category = Category.WALL
	display_name = "Wrap Around"
	description = "Balls hitting the left/right wall reappear on the opposite side."

func on_wall_hit(rules: GameRules, ball: Ball, collision: KinematicCollision2D) -> bool:
	if absf(collision.get_normal().x) <= SIDE_NORMAL_THRESHOLD:
		return false
	# Mirroring about the playfield centre lands the ball against the
	# opposite wall's face.
	var mirror := rules.play_left + rules.play_right
	ball.global_position.x = mirror - ball.global_position.x + signf(ball.direction.x) * EXIT_NUDGE
	return true

## A ball leaving through the left wall and coming back in on the right.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	for u in [0.06, 0.94]:
		var x := PreviewDraw.at(r, u, 0.0).x
		var y := r.position.y + r.size.y * 0.1
		while y < r.end.y - r.size.y * 0.1:
			c.draw_line(Vector2(x, y), Vector2(x, y + r.size.y * 0.05), PreviewDraw.ACCENT, 2.0)
			y += r.size.y * 0.09
	var p := PreviewDraw.phase(t, 2.4)
	var u := 0.5 - p * 2.0 * 0.42 if p < 0.5 else 0.92 - (p - 0.5) * 2.0 * 0.42
	var pos := PreviewDraw.at(r, u, 0.8 - p * 0.55)
	c.draw_line(pos, pos + Vector2(PreviewDraw.px(r, 0.15), PreviewDraw.px(r, 0.2)), Color(PreviewDraw.GLOW, 0.4), 2.0)
	PreviewDraw.ball(c, pos, PreviewDraw.px(r, 0.06))
	PreviewDraw.text(c, PreviewDraw.at(r, 0.5, 0.18), "<->", int(PreviewDraw.px(r, 0.16)), PreviewDraw.ACCENT)
