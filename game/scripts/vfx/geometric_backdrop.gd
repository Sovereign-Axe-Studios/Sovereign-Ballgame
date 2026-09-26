class_name GeometricBackdrop
extends Node2D
## Drifting, slowly rotating wireframe polygons in NeonUI's cyan and magenta,
## at three depths, with a gentle parallax that follows the mouse. The
## backdrop for the title, Mode Select, the Asset Viewer and the pause menu,
## and (as the "Geometric" background skin) the playfield itself.

const COUNT := 26
## Parallax pixels at full mouse offset, per depth layer (near moves most).
const PARALLAX := [10.0, 26.0, 48.0]
## Wrap margin so polygons drift fully off-screen before reappearing.
const WRAP := 220.0

## Faint mode for behind a dimmed menu: lower alpha, no parallax.
var faint: bool = false
var fill_background: bool = true

var _view := Vector2.ZERO
var _shapes: Array[Dictionary] = []
var _t: float = 0.0
var _mouse := Vector2.ZERO

func _ready() -> void:
	_view = NeonUI.view_size()
	for i in range(COUNT):
		_shapes.append(_new_shape(Vector2(randf() * _view.x, randf() * _view.y)))

func _new_shape(pos: Vector2) -> Dictionary:
	var depth := randi_range(0, 2)
	return {
		"pos": pos,
		"sides": randi_range(3, 8),
		"radius": randf_range(40.0, 150.0) * (0.6 + depth * 0.35),
		"rot": randf() * TAU,
		"spin": randf_range(-0.25, 0.25),
		"drift": Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0)),
		"depth": depth,
		"magenta": randf() < 0.45,
		"burst": 0.0,
	}

func _process(delta: float) -> void:
	_t += delta
	if not faint:
		var m := get_viewport().get_mouse_position() / _view - Vector2(0.5, 0.5)
		_mouse = _mouse.lerp(m, clampf(delta * 3.0, 0.0, 1.0))
	for s in _shapes:
		s.rot += s.spin * delta
		s.pos += s.drift * delta
		s.pos.x = wrapf(s.pos.x, -WRAP, _view.x + WRAP)
		s.pos.y = wrapf(s.pos.y, -WRAP, _view.y + WRAP)
		s.burst = maxf(0.0, s.burst - delta)
	queue_redraw()

## Every polygon bursts outward from `from`, then eases back (board cleared).
func burst(from: Vector2) -> void:
	for s in _shapes:
		s.burst = 1.2
		s.drift += (s.pos - from).normalized() * 60.0

## A fresh polygon spins up at `pos` (new ball).
func spawn_at(pos: Vector2) -> void:
	var s := _new_shape(pos)
	s.radius = 10.0
	s.spin = 3.0
	_shapes.append(s)
	if _shapes.size() > COUNT + 8:
		_shapes.remove_at(0)

func _draw() -> void:
	if fill_background:
		draw_rect(Rect2(Vector2.ZERO, _view), NeonUI.BG, true)
	for s in _shapes:
		# A spun-up newcomer grows to full size and calms its spin.
		if s.radius < 60.0:
			s.radius += 1.5
			s.spin = lerpf(s.spin, 0.2, 0.02)
		var depth: int = s.depth
		var offset: Vector2 = _mouse * float(PARALLAX[depth])
		var alpha := (0.16 + depth * 0.12) * (0.45 if faint else 1.0)
		var color: Color = NeonUI.MAGENTA if s.magenta else NeonUI.CYAN
		color.a = clampf(alpha + float(s.burst) * 0.5, 0.0, 1.0)
		var r: float = s.radius * (1.0 + float(s.burst) * 0.4)
		var pts := PackedVector2Array()
		var sides: int = s.sides
		for i in range(sides + 1):
			var a: float = s.rot + TAU * i / sides
			pts.append(s.pos + offset + Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, color, 1.5 + depth * 0.8, true)
