extends GameMod
## Circles -- every block is round. Physics gives the curved bounce normals.

func _init() -> void:
	category = Category.SHAPE
	display_name = "Circles"
	description = "Blocks are circles."

func configure_block(_rules: GameRules, block: Block) -> void:
	block.set_shape(Block.Shape.CIRCLE)
