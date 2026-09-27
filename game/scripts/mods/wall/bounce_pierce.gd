extends GameMod
## Bounce Pierce -- balls fly through blocks, damaging each one once, and
## burn out after a few side-wall bounces. Aim becomes drawing a line through
## the field.

## Side-wall bounces before the ball burns out (the ceiling doesn't count).
const MAX_SIDE_BOUNCES := 3
## Block collision layer (scenes/block.tscn), taken out of the ball's mask.
const BLOCK_LAYER := 2

var _field: Playfield

func _init() -> void:
	category = Category.WALL
	display_name = "Bounce Pierce"
	description = "Balls pierce blocks (hitting each once) and burn out after %d side bounces." % MAX_SIDE_BOUNCES

func on_run_start(_rules: GameRules, field: Playfield) -> void:
	_field = field

func configure_ball(_rules: GameRules, ball: Ball) -> void:
	ball.collision_mask &= ~BLOCK_LAYER

func on_ball_moved(rules: GameRules, ball: Ball) -> void:
	if _field == null:
		return
	var block := _field.grid.block_at(ball.global_position)
	if block != null and not ball.mod_state.has(block.get_instance_id()):
		ball.mod_state[block.get_instance_id()] = true
		var dealt := block.hit(rules.damage_for(ball))
		ball.block_damaged.emit(block, dealt)
	if ball.side_bounces >= MAX_SIDE_BOUNCES:
		ball.finish()

## A ball punching straight through a column of blocks.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var s := PreviewDraw.px(r, 0.2)
	var p := PreviewDraw.phase(t, 2.0)
	for i in range(3):
		var y := 0.25 + i * 0.2
		var cracked := p > 1.0 - y
		PreviewDraw.block(c, PreviewDraw.at(r, 0.5, y), s * (0.85 if cracked else 1.0), 3 - (1 if cracked else 0))
	var pos := PreviewDraw.at(r, 0.5, 1.0 - p * 0.95)
	c.draw_line(pos, pos + Vector2(0, PreviewDraw.px(r, 0.18)), Color(PreviewDraw.GLOW, 0.5), 3.0)
	PreviewDraw.ball(c, pos, PreviewDraw.px(r, 0.055))
