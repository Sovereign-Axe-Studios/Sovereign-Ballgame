extends GameMod
## 5° x N -- every block tilted by the same angle.

## One step of tilt, in degrees.
const STEP_DEGREES := 5.0
## How many steps. Total tilt = STEP_DEGREES * N.
const N := 3

func _init() -> void:
	category = Category.ROTATION
	display_name = "%d° Tilt" % int(STEP_DEGREES * N)
	description = "All blocks rotated by %s° x %d." % [STEP_DEGREES, N]

func configure_block(_rules: GameRules, block: Block) -> void:
	var theta := deg_to_rad(STEP_DEGREES * N)
	# A square rotated by theta spans (cos + sin) of its side along each
	# axis; shrink by that so it still fits its cell and never overlaps a
	# neighbour.
	var fit := 1.0 / (absf(cos(theta)) + absf(sin(theta)))
	block.set_tilt(STEP_DEGREES * N, fit)

## A block tilting from square to its final angle, over its old outline.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var size := PreviewDraw.px(r, 0.46)
	var center := PreviewDraw.at(r, 0.5, 0.45)
	c.draw_rect(Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size), PreviewDraw.FRAME, false, 2.0)
	var f := minf(1.0, PreviewDraw.phase(t, 2.4) * 2.0)
	PreviewDraw.block(c, center, size, 3, STEP_DEGREES * N * f)
	PreviewDraw.text(c, PreviewDraw.at(r, 0.5, 0.85), "%d°" % roundi(STEP_DEGREES * N * f),
		int(PreviewDraw.px(r, 0.13)), Palette.TEXT_DIM)
