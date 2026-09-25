extends GameMod
## Circles -- every block is round. Physics gives the curved bounce normals.

func _init() -> void:
	category = Category.SHAPE
	display_name = "Circles"
	description = "Blocks are circles."

func configure_block(_rules: GameRules, block: Block) -> void:
	block.set_shape(Block.Shape.CIRCLE)

## A square block rounding off into a circle and back.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var m := (sin(t * 2.0) + 1.0) * 0.5
	PreviewDraw.block(c, r.get_center(), PreviewDraw.px(r, 0.5), 5, 0.0, m)
