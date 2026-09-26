class_name Block
extends StaticBody2D
## One numbered brick. Value == hits remaining.

signal destroyed(block: Block)

## Collider + drawing outline. SHAPE mods pick one via set_shape().
enum Shape { SQUARE, CIRCLE }

## Inset on each side of the cell, as a fraction of cell size, so neighbouring
## blocks read as separate bricks and a ball squeezing down a seam does not
## scrape two colliders at once.
const INSET_FRACTION := 0.06

var value: int = 1
## What the block spawned with, so the break sound can tell a big block from a small one.
var start_value: int = 1
var grid_col: int = 0
var grid_row: int = 0

var _size: float = 100.0
var _color := Color.WHITE
var _shape_kind: Shape = Shape.SQUARE
var _body_scale: float = 1.0

@onready var _shape: CollisionShape2D = $Collision
@onready var _label: Label = $Value

func _ready() -> void:
	Skins.changed.connect(_refresh)

func get_color() -> Color:
	return _color

func get_size() -> float:
	return _size

## Call after adding to the tree.
func setup(start_value: int, cell_size: float, col: int, row: int) -> void:
	value = maxi(1, start_value)
	self.start_value = value
	_size = cell_size
	grid_col = col
	grid_row = row
	_rebuild_body()
	_refresh()

## SHAPE mods. Rebuilds the collider and redraws.
func set_shape(kind: Shape) -> void:
	_shape_kind = kind
	_rebuild_body()

## ROTATION mods. Rotates the block, shrinks it by `body_scale` (so a rotated
## square still fits its cell), and keeps the value label upright.
func set_tilt(degrees: float, body_scale: float) -> void:
	rotation_degrees = degrees
	_body_scale = body_scale
	_rebuild_body()
	_label.rotation = -rotation

## Side length (or diameter) of the visible/colliding body.
func _body_size() -> float:
	return (_size - _size * INSET_FRACTION * 2.0) * _body_scale

func _rebuild_body() -> void:
	var body := _body_size()
	if _shape_kind == Shape.CIRCLE:
		var circle := CircleShape2D.new()
		circle.radius = body * 0.5
		_shape.shape = circle
	else:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(body, body)
		_shape.shape = rect

	_label.offset_left = -body * 0.5
	_label.offset_top = -body * 0.5
	_label.offset_right = body * 0.5
	_label.offset_bottom = body * 0.5
	_label.pivot_offset = Vector2(body, body) * 0.5
	_label.add_theme_font_size_override("font_size", int(body * 0.34))
	queue_redraw()

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
	var body := _body_size()
	var outline := maxf(2.0, _size * 0.025)
	if _shape_kind == Shape.CIRCLE:
		draw_circle(Vector2.ZERO, body * 0.5, _color)
		draw_arc(Vector2.ZERO, body * 0.5, 0.0, TAU, 48, _color.lightened(0.25), outline)
		return
	var r := Rect2(Vector2(-body * 0.5, -body * 0.5), Vector2(body, body))
	draw_rect(r, _color, true)
	draw_rect(r, _color.lightened(0.25), false, outline)
