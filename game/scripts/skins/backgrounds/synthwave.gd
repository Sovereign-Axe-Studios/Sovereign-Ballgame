extends AnimatedBackground
## Synthwave -- a striped sunset sun over a scrolling neon horizon grid.
## Board cleared: the sun flares and a bright pulse races down the grid.
## New ball: a neon ring ripples out along the horizon.

const SKY := Color("#1a0b2e")
const SUN_TOP := Color("#ffd166")
const SUN_BOTTOM := Color("#ff4f8b")
const GRID := Color("#ff4fd8")
const HORIZON_Y := 0.42   ## fraction of screen height
const SUN_RADIUS := 260.0
const GRID_LINES := 16
const SCROLL_SPEED := 0.35

var _flare: float = 0.0
var _pulse: float = -1.0
var _rings: Array[Vector2] = []  ## x = screen x, y = age

func on_board_cleared(_pos: Vector2) -> void:
	_flare = 1.0
	_pulse = 0.0

func on_new_ball(pos: Vector2) -> void:
	_rings.append(Vector2(pos.x, 0.0))

func _process(delta: float) -> void:
	super(delta)
	_flare = maxf(0.0, _flare - delta * 0.8)
	if _pulse >= 0.0:
		_pulse += delta * 0.9
		if _pulse > 1.0:
			_pulse = -1.0
	for i in range(_rings.size()):
		_rings[i].y += delta
	_rings = _rings.filter(func(ring: Vector2) -> bool: return ring.y < 1.5)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), SKY, true)
	var horizon := view.y * HORIZON_Y
	var cx := view.x * 0.5
	var r := SUN_RADIUS * (1.0 + _flare * 0.25)
	if _flare > 0.0:
		draw_circle(Vector2(cx, horizon), r * 1.4, Color(SUN_BOTTOM, _flare * 0.3))
	# The sun, as horizontal slices, with gaps widening toward the horizon.
	var y := horizon - r
	while y < horizon:
		var f := (y - (horizon - r)) / r
		var half := sqrt(maxf(0.0, r * r - pow(horizon - y, 2.0)))
		var gap := f > 0.55 and int((y - horizon) / 14.0) % 2 == 0
		if not gap:
			draw_line(Vector2(cx - half, y), Vector2(cx + half, y), SUN_TOP.lerp(SUN_BOTTOM, f), 5.0)
		y += 5.0
	draw_rect(Rect2(0, horizon, view.x, view.y - horizon), SKY.darkened(0.3), true)
	# Horizontal grid lines, bunched toward the horizon, scrolling toward us.
	var scroll := fposmod(t * SCROLL_SPEED, 1.0)
	for k in range(GRID_LINES):
		var d := pow((k + scroll) / GRID_LINES, 2.0)
		var gy := horizon + d * (view.y - horizon)
		var col := GRID
		col.a = 0.25 + d * 0.6
		if _pulse >= 0.0 and absf(d - _pulse) < 0.06:
			col = Color.WHITE
		draw_line(Vector2(0, gy), Vector2(view.x, gy), col, 2.0 + d * 2.0)
	for k in range(-12, 13):
		draw_line(Vector2(cx + k * 30.0, horizon), Vector2(cx + k * 260.0, view.y), Color(GRID, 0.45), 2.0)
	for ring in _rings:
		var w := ring.y * 700.0
		draw_polyline(BallLook.ellipse_points(Vector2(ring.x, horizon + 30.0), w, w * 0.12, 0.0, 0.0, TAU, 40),
			Color(Color("#4ff0ff"), 1.0 - ring.y / 1.5), 4.0, true)
