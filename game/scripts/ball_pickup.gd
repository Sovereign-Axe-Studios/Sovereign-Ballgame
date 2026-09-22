class_name BallPickup
extends Area2D
## +1 ball, banked and applied at the end of the round.

signal collected(pickup: BallPickup)

var grid_col: int = 0
var grid_row: int = 0
var _radius: float = 26.0
var _taken := false
var _t := 0.0

@onready var _shape: CollisionShape2D = $Collision

func setup(cell_size: float, col: int, row: int) -> void:
	grid_col = col
	grid_row = row
	_radius = cell_size * 0.22
	var circle := CircleShape2D.new()
	circle.radius = _radius
	_shape.shape = circle
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if _taken or not (body is Ball):
		return
	_taken = true
	collected.emit(self)
	queue_free()

func _draw() -> void:
	var pulse := 1.0 + sin(_t * 3.4) * 0.08
	draw_arc(Vector2.ZERO, _radius * 1.55 * pulse, 0.0, TAU, 28, Palette.PICKUP, 3.0, true)
	draw_circle(Vector2.ZERO, _radius * pulse, Palette.PICKUP)
