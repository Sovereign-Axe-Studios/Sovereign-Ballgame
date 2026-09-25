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
