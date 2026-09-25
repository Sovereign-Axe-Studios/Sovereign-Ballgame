extends GameMod
## Lives -- a row reaching the end zone costs a life instead of the run. The
## run ends when the last life goes.

const START_LIVES := 3

## Per-run state. Run stores mod scripts, not instances, so every run
## (including an R restart) gets a fresh mod and a full set of lives.
var lives_left: int = START_LIVES

func _init() -> void:
	category = Category.LOSS
	display_name = "Lives"
	description = "%d lives; a row reaching the bottom costs one." % START_LIVES

## One life per shift, however many blocks landed together -- the GDD's "a
## row reaching the end zone".
func on_death_row_reached(_rules: GameRules, blocks: Array[Block]) -> bool:
	lives_left -= 1
	for block in blocks:
		if is_instance_valid(block):
			block.hit(block.value)
	return lives_left > 0

func status_text(_rules: GameRules) -> String:
	return "LIVES %d" % maxi(0, lives_left)
