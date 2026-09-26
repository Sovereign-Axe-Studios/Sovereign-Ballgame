extends AnimatedBackground
## Geometric -- the title screen's drifting neon polygons (GeometricBackdrop)
## behind the playfield. Board cleared: every polygon bursts outward and
## re-forms. New ball: a new polygon spins up at the landing spot.

var _backdrop: GeometricBackdrop

func _ready() -> void:
	super()
	_backdrop = GeometricBackdrop.new()
	add_child(_backdrop)

func on_board_cleared(pos: Vector2) -> void:
	_backdrop.burst(pos)

func on_new_ball(pos: Vector2) -> void:
	_backdrop.spawn_at(pos)
