extends GameMod
## Random Rotation -- every block gets its own angle. Chaos to Tilt's order.

const MAX_DEGREES := 90.0

func _init() -> void:
	category = Category.ROTATION
	display_name = "Random Tilt"
	description = "Every block is rotated to its own random angle."

func configure_block(_rules: GameRules, block: Block) -> void:
	var degrees := randf_range(0.0, MAX_DEGREES)
	var theta := deg_to_rad(degrees)
	# Shrink so the rotated square still fits its cell (see rotated.gd).
	block.set_tilt(degrees, 1.0 / (absf(cos(theta)) + absf(sin(theta))))

## A little grid of blocks at jumbled angles, slowly settling.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var angles := [12.0, 61.0, 33.0, 80.0]
	for i in range(4):
		var center := PreviewDraw.at(r, 0.3 + (i % 2) * 0.4, 0.3 + (i / 2) * 0.4)
		PreviewDraw.block(c, center, PreviewDraw.px(r, 0.26), 2 + i, angles[i] + sin(t * 1.5 + i) * 8.0)
