class_name Block
extends StaticBody2D
## One numbered brick. Value == hits remaining.

signal destroyed(block: Block)

var value: int = 1
var grid_col: int = 0
var grid_row: int = 0

var _size: float = 100.0
var _color := Color.WHITE

@onready var _shape: CollisionShape2D = $Collision
@onready var _label: Label = $Value

## Call after adding to the tree.
func setup(start_value: int, cell_size: float, col: int, row: int) -> void:
	value = maxi(1, start_value)
	_size = cell_size
	grid_col = col
	grid_row = row

	# A hair of inset so neighbouring blocks read as separate bricks and a ball
	# squeezing down a seam does not scrape two colliders at once.
	var inset := cell_size * 0.06
	var body := cell_size - inset * 2.0
	var rect := RectangleShape2D.new()
	rect.size = Vector2(body, body)
	_shape.shape = rect

	_label.offset_left = -body * 0.5
	_label.offset_top = -body * 0.5
	_label.offset_right = body * 0.5
	_label.offset_bottom = body * 0.5
	_label.add_theme_font_size_override("font_size", int(body * 0.34))

	_refresh()

## Returns damage actually absorbed.
func hit(damage: int = 1) -> int:
	var dealt := mini(damage, value)
	value -= damage
	if value <= 0:
		destroyed.emit(self)
		queue_free()
	else:
		_refresh()
	return dealt

func _refresh() -> void:
	_color = Palette.health_color(value)
	_label.text = str(value)
	_label.add_theme_color_override("font_color", Palette.label_color(_color))
	queue_redraw()

func _draw() -> void:
	var inset := _size * 0.06
	var body := _size - inset * 2.0
	var r := Rect2(Vector2(-body * 0.5, -body * 0.5), Vector2(body, body))
	draw_rect(r, _color, true)
	draw_rect(r, _color.lightened(0.25), false, maxf(2.0, _size * 0.025))
