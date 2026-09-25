extends GameMod
## Time Rewind -- 22 seconds after the round's first shot, time loops: every
## ball still in play plays its path back to the shooter, and any shots not
## yet fired are cancelled. Damage already dealt stays dealt.
## Unlocked by the title-screen constellation.

## Seconds after the first shot before the loop resets. 22, for the minutes.
const REWIND_AFTER := 22.0
## Playback speed of the rewind, x real time.
const REWIND_SPEED := 2.0

## The round's firing clock restarts at 0 each round; seeing it go backwards
## means a new round, so the rewind can fire again.
var _last_seconds: float = 0.0
var _rewound: bool = false

func _init() -> void:
	category = Category.BALL_COLLISION
	display_name = "Time Rewind"
	description = "After %d seconds, every ball still out rewinds along its path, and no more fire." % int(REWIND_AFTER)
	locked_by = Unlocks.OUTER_WILDS
	# A 22-second wait makes a poor preview; the ? panel loops the sketch.
	live_preview = false

func wants_path_recording(_rules: GameRules) -> bool:
	return true

func on_firing_tick(_rules: GameRules, game: Game, seconds: float) -> void:
	if seconds < _last_seconds:
		_rewound = false
	_last_seconds = seconds
	if _rewound or seconds < REWIND_AFTER:
		return
	_rewound = true
	for ball in game.live_balls():
		ball.start_rewind(REWIND_SPEED)
	var ring := RewindRing.new()
	game.effects_root.add_child(ring)
	ring.global_position = game.shooter.global_position
	game.stop_firing()


## A ball bouncing out along a path, then running it backwards in blue.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var path: Array[Vector2] = [
		PreviewDraw.at(r, 0.5, 0.9), PreviewDraw.at(r, 0.12, 0.45),
		PreviewDraw.at(r, 0.6, 0.1), PreviewDraw.at(r, 0.88, 0.5), PreviewDraw.at(r, 0.55, 0.75),
	]
	for i in range(path.size() - 1):
		c.draw_line(path[i], path[i + 1], PreviewDraw.FRAME, 1.5)
	var p := PreviewDraw.phase(t, 3.0)
	var forward := p < 0.6
	var f := p / 0.6 if forward else 1.0 - (p - 0.6) / 0.4
	var seg := f * float(path.size() - 1)
	var i := mini(int(seg), path.size() - 2)
	var pos := path[i].lerp(path[i + 1], seg - float(i))
	PreviewDraw.ball(c, pos, PreviewDraw.px(r, 0.06), Color.TRANSPARENT if forward else Ball.REWIND_COLOR)
	var clock := "22s" if forward else "<<"
	PreviewDraw.text(c, PreviewDraw.at(r, 0.82, 0.1), clock, int(PreviewDraw.px(r, 0.13)),
		PreviewDraw.GLOW if forward else Ball.REWIND_COLOR)


## One blue ring pulsing out from the shooter as the loop resets.
class RewindRing extends Node2D:
	const DURATION := 0.9
	const MAX_RADIUS := 900.0
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= DURATION:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var f := _t / DURATION
		draw_arc(Vector2.ZERO, MAX_RADIUS * f, 0.0, TAU, 96, Color(Ball.REWIND_COLOR, 1.0 - f), 6.0)
