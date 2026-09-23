class_name BlockFragment
extends Node2D
## One piece of a destroyed block: cracks apart, tumbles a short fall, and
## fades. Built via `.new()` + `setup()`, no scene -- see BlockChunk.
##
## Size is a Vector2, not a single float -- GameRules.fragment_cols/rows_*
## can differ, so a piece is generally rectangular, not square (a 3-wide,
## 2-tall split makes pieces wider than they are tall).
##
## "Falls to the ground and fades" here means a short local fall, not a
## flight all the way to the play field's floor_y -- a block near the top of
## a 9-row grid can be well over a thousand pixels above the actual floor,
## and covering that in under a second would look like the fragment being
## launched rather than dropped. Revisit if the far-from-floor case reads
## wrong in practice.

var _color := Color.WHITE
var _size := Vector2(20.0, 20.0)
var _vel := Vector2.ZERO
var _spin: float = 0.0
var _age: float = 0.0
var _lifetime: float = 0.7

const GRAVITY := 700.0

func setup(color: Color, size: Vector2, vel: Vector2, lifetime: float, spin: float) -> void:
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
	# Ease-in fade: reads as solid debris for a beat, then dissolves, rather
	# than visibly graying out from the first frame.
	var t := _age / _lifetime
	modulate.a = 1.0 - t * t
	queue_redraw()

func _draw() -> void:
	var r := Rect2(_size * -0.5, _size)
	draw_rect(r, _color, true)
	draw_rect(r, _color.darkened(0.35), false, maxf(1.5, minf(_size.x, _size.y) * 0.03))
