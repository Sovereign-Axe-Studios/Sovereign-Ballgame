class_name NomaiConstellation
extends Node2D
## The title screen's easter egg: ~20 slightly-off stars hidden in the
## starfield, tracing the Nomai emblem (four curved outer arms, the central
## mask). Click them in any order; an edge draws once both of its ends are
## lit. Light them all and the emblem blooms, `completed` fires, and MainMenu
## unlocks the Outer Wilds extras.
##
## Once unlocked, it stays on the title fully linked but dim, and ignores
## clicks: a quiet trophy.

signal completed

## Emblem points, as fractions of AREA. Traced by hand from the reference
## emblem: arcs listed outer-end to inner-end.
const POINTS: Array[Vector2] = [
	# 0-3 upper-left arm
	Vector2(0.13, 0.27), Vector2(0.22, 0.12), Vector2(0.35, 0.04), Vector2(0.46, 0.03),
	# 4-7 upper-right arm
	Vector2(0.87, 0.27), Vector2(0.78, 0.12), Vector2(0.65, 0.04), Vector2(0.54, 0.03),
	# 8-11 lower-left arm
	Vector2(0.06, 0.52), Vector2(0.10, 0.70), Vector2(0.22, 0.87), Vector2(0.40, 0.97),
	# 12-15 lower-right arm
	Vector2(0.94, 0.52), Vector2(0.90, 0.70), Vector2(0.78, 0.87), Vector2(0.60, 0.97),
	# 16-19 mask: top, left, right, chin
	Vector2(0.50, 0.29), Vector2(0.32, 0.47), Vector2(0.68, 0.47), Vector2(0.50, 0.78),
]

const EDGES: Array[Vector2i] = [
	# the four arms
	Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3),
	Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7),
	Vector2i(8, 9), Vector2i(9, 10), Vector2i(10, 11),
	Vector2i(12, 13), Vector2i(13, 14), Vector2i(14, 15),
	# the mask diamond
	Vector2i(16, 17), Vector2i(16, 18), Vector2i(17, 19), Vector2i(18, 19),
	# struts: mask to the top hooks and to the lower arms
	Vector2i(16, 3), Vector2i(16, 7), Vector2i(17, 9), Vector2i(18, 13),
]

## Where the emblem sits on the 1080-wide title screen (behind the title).
const AREA := Rect2(200.0, 70.0, 680.0, 680.0)
## Nomai amber, a touch warmer than the white ambient stars.
const STAR_COLOR := Color("#f2c27a")
const LINE_COLOR := Color("#f2b35a")
const STAR_RADIUS := 2.8
## Generous, since the stars are tiny.
const CLICK_RADIUS := 28.0
## Ambient stars twinkle at 1.6 rad/s (MainMenu); these at half that.
const TWINKLE_SPEED := 0.8
const EDGE_FADE_IN := 0.6
const BLOOM_SECONDS := 1.5

var _lit: Array[bool] = []
var _edge_lit_at: Dictionary = {} ## edge index -> time it appeared
var _phase: Array[float] = []
var _t: float = 0.0
var _hover: int = -1
var _bloom_start: float = -1.0
var _done: bool = false

func _ready() -> void:
	_done = Unlocks.is_unlocked(Unlocks.OUTER_WILDS)
	for i in range(POINTS.size()):
		_lit.append(_done)
		_phase.append(randf() * TAU)
	if _done:
		for e in range(EDGES.size()):
			_edge_lit_at[e] = -INF

func _process(delta: float) -> void:
	_t += delta
	_hover = -1 if _done else _star_at(get_global_mouse_position())
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if _done or not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var i := _star_at((make_input_local(mb) as InputEventMouseButton).position)
	if i < 0 or _lit[i]:
		return
	_lit[i] = true
	for e in range(EDGES.size()):
		if not _edge_lit_at.has(e) and _lit[EDGES[e].x] and _lit[EDGES[e].y]:
			_edge_lit_at[e] = _t
	get_viewport().set_input_as_handled()
	if not _lit.has(false):
		_done = true
		_bloom_start = _t
		completed.emit()

func _star_at(point: Vector2) -> int:
	for i in range(POINTS.size()):
		if _pos(i).distance_to(point) <= CLICK_RADIUS:
			return i
	return -1

func _pos(i: int) -> Vector2:
	var p := AREA.position + POINTS[i] * AREA.size
	if _bloom_start >= 0.0:
		# Swell ~5% from the centre over the bloom, then ease back.
		var k := sin(clampf((_t - _bloom_start) / BLOOM_SECONDS, 0.0, 1.0) * PI) * 0.05
		p = AREA.get_center() + (p - AREA.get_center()) * (1.0 + k)
	return p

func _draw() -> void:
	var blooming := _bloom_start >= 0.0 and _t - _bloom_start < BLOOM_SECONDS
	var flash := 0.0
	if blooming:
		flash = sin((_t - _bloom_start) / BLOOM_SECONDS * PI)
	# A finished constellation seen on a later visit rests dim.
	var trophy := _done and _bloom_start < 0.0

	for e in range(EDGES.size()):
		if not _edge_lit_at.has(e):
			continue
		var a := clampf((_t - float(_edge_lit_at[e])) / EDGE_FADE_IN, 0.0, 1.0)
		var color := LINE_COLOR
		color.a = (0.25 if trophy else 0.7) * a + flash * 0.3
		draw_line(_pos(EDGES[e].x), _pos(EDGES[e].y), color, 2.0 + flash * 2.0, true)

	for i in range(POINTS.size()):
		var twinkle := 0.45 + 0.3 * sin(_t * TWINKLE_SPEED + _phase[i])
		var r := STAR_RADIUS
		var color := STAR_COLOR
		if _lit[i]:
			twinkle = 0.5 if trophy else 1.0
			r *= 1.4
		if i == _hover:
			var pulse := 0.5 + 0.5 * sin(_t * 6.0)
			r *= 1.5 + 0.4 * pulse
			twinkle = 1.0
			draw_arc(_pos(i), r * 3.0, 0.0, TAU, 24, Color(STAR_COLOR, 0.25 + 0.25 * pulse), 1.5)
		if _lit[i] and not trophy:
			draw_arc(_pos(i), r * 2.4, 0.0, TAU, 24, Color(STAR_COLOR, 0.35), 1.5)
		color.a = clampf(twinkle + flash, 0.0, 1.0)
		draw_circle(_pos(i), r * (1.0 + flash), color)
