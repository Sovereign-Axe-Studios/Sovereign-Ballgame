extends GameMod
## Poison -- hits deal no damage now; each adds poison stacks to the block.
## Stacks never wear off, and at every round end each poisoned block takes
## damage equal to its stacks. Slow to start, brutal once it builds.

const STACKS_PER_HIT := 1
const META := &"poison_stacks"

func _init() -> void:
	category = Category.BALL_COLLISION
	display_name = "Poison"
	description = "Hits add +%d poison instead of damage. Each round, blocks take their poison." % STACKS_PER_HIT
	# The preview board has no round ends, so the ticks would never show.
	live_preview = false

func damage_for(_rules: GameRules, _ball: Ball) -> int:
	return 0

func on_block_hit(_rules: GameRules, _ball: Ball, block: Block) -> void:
	if not is_instance_valid(block) or block.value <= 0:
		return
	var stacks: int = int(block.get_meta(META, 0)) + STACKS_PER_HIT
	block.set_meta(META, stacks)
	block.badge = "☠%d" % stacks

func on_round_end(_rules: GameRules, field: Playfield) -> void:
	for row: Array in field.grid.cells:
		for item in row:
			if item is Block and int((item as Block).get_meta(META, 0)) > 0:
				var block := item as Block
				block.hit(int(block.get_meta(META, 0)))

## A block ticking down as its poison counter climbs.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var stacks := 1 + int(PreviewDraw.phase(t, 3.0) * 4.0)
	var value := maxi(1, 12 - stacks * 2)
	var center := PreviewDraw.at(r, 0.5, 0.5)
	PreviewDraw.block(c, center, PreviewDraw.px(r, 0.46), value)
	PreviewDraw.text(c, center + Vector2(0, -PreviewDraw.px(r, 0.36)), "☠%d" % stacks,
		int(PreviewDraw.px(r, 0.15)), Color("#7dff6a"))
