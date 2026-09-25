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

func on_wall_hit(_rules: GameRules, ball: Ball, collision: KinematicCollision2D) -> bool:
	if absf(collision.get_normal().x) <= SIDE_NORMAL_THRESHOLD:
		return false
	# The playfield is symmetric (side_margin both sides), so mirroring about
	# the viewport centre lands the ball against the opposite wall's face.
	var vp_w := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	ball.global_position.x = vp_w - ball.global_position.x + signf(ball.direction.x) * EXIT_NUDGE
	return true
