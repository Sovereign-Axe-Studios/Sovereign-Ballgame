class_name BlockChunk
extends Node2D
## A small piece of debris popped out by a non-fatal hit. Built via `.new()`
## + `setup()`, no scene -- matches the rest of the project's "draw
## primitives in code" style (Palette/Block/Ball all do the same).

var _color := Color.WHITE
var _size: float = 6.0
var _vel := Vector2.ZERO
var _spin: float = 0.0
var _age: float = 0.0
var _lifetime: float = 0.4

const GRAVITY := 900.0

func setup(color: Color, size: float, vel: Vector2, lifetime: float, spin: float) -> void:
	_color = color
	_size = size
	_vel = vel
	_lifetime = lifetime
	_spin = spin
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return
	_vel.y += GRAVITY * delta
	position += _vel * delta
	rotation += _spin * delta
	modulate.a = 1.0 - (_age / _lifetime)
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2(-_size * 0.5, -_size * 0.5), Vector2(_size, _size))
	draw_rect(r, _color, true)
