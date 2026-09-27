extends GameMod
## Triangles -- every block is a triangle, pointing up or down on a
## checkerboard so rows tessellate. Sharp, unpredictable bounce angles.

func _init() -> void:
	category = Category.SHAPE
	display_name = "Triangles"
	description = "Blocks are triangles, alternating up and down."

func configure_block(_rules: GameRules, block: Block) -> void:
	block.set_shape(Block.Shape.TRIANGLE, (block.grid_col + block.grid_row) % 2 == 1)

## A tessellating row of up and down triangles.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var s := PreviewDraw.px(r, 0.3)
	for i in range(4):
		var center := PreviewDraw.at(r, 0.2 + i * 0.2, 0.5)
		var up := i % 2 == 0
		var h := s * 0.5
		var pts := PackedVector2Array([center + Vector2(-h, h), center + Vector2(h, h), center + Vector2(0, -h)]) if up \
			else PackedVector2Array([center + Vector2(-h, -h), center + Vector2(h, -h), center + Vector2(0, h)])
		var col := Palette.health_color(20 + i * 18)
		c.draw_colored_polygon(pts, col.lightened(0.15 * sin(t * 3.0 + i)))
