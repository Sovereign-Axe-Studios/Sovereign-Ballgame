extends GameMod
## Modified grid -- a custom board size. The layout already sizes cells from
## the grid, so this is value-only.

const WIDTH := 9
## Includes the spawn row (0) and the death row (HEIGHT - 1).
const HEIGHT := 11

func _init() -> void:
	category = Category.GRID
	display_name = "%dx%d Grid" % [WIDTH, HEIGHT]
	description = "A %d wide, %d tall board." % [WIDTH, HEIGHT]

func apply(rules: GameRules) -> void:
	rules.grid_width = WIDTH
	rules.grid_height = HEIGHT
