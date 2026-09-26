extends AnimatedBackground
## Lava lamp -- warm blobs rising, wobbling and merging.
## Board cleared: every blob pops, then they re-bubble from the bottom.
## New ball: a new blob rises from where the ball landed.

const BG := Color("#1c0b12")
const COLORS: Array[Color] = [Color("#ff6b35"), Color("#ff3d7f"), Color("#ffb347")]
const COUNT := 11

var _blobs: Array[Dictionary] = []
var _pops: Array[Dictionary] = []

func _ready() -> void:
	super()
	for i in range(COUNT):
		_blobs.append(_new_blob(Vector2(randf() * view.x, randf() * view.y)))

func _new_blob(pos: Vector2) -> Dictionary:
	return {"pos": pos, "r": randf_range(50.0, 120.0), "speed": randf_range(25.0, 60.0),
		"phase": randf() * TAU, "color": COLORS[randi() % COLORS.size()]}

func on_board_cleared(_pos: Vector2) -> void:
	for b in _blobs:
		_pops.append({"pos": b.pos, "r": b.r, "color": b.color, "age": 0.0})
	_blobs.clear()
	for i in range(COUNT):
		_blobs.append(_new_blob(Vector2(randf() * view.x, view.y + randf_range(60.0, 500.0))))

func on_new_ball(pos: Vector2) -> void:
	var b := _new_blob(pos)
	b.r = 20.0
	_blobs.append(b)
	if _blobs.size() > COUNT + 6:
		_blobs.remove_at(0)

func _process(delta: float) -> void:
	super(delta)
	for b in _blobs:
		b.pos.y -= b.speed * delta
		b.pos.x += sin(t * 0.6 + b.phase) * 12.0 * delta
		b.r = minf(b.r + delta * 20.0, 130.0) if b.r < 50.0 else b.r
		if b.pos.y < -b.r * 1.5:
			b.pos = Vector2(randf() * view.x, view.y + b.r * 1.5)
	for p in _pops:
		p.age += delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p.age < 0.6)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), BG, true)
	for b in _blobs:
		var wobble := 1.0 + 0.08 * sin(t * 1.3 + b.phase)
		var halo := BallLook.ellipse_points(b.pos, b.r / wobble * 1.35, b.r * wobble * 1.55, 0.0, 0.0, TAU, 28)
		draw_colored_polygon(halo, Color(b.color, 0.12))
		var pts := BallLook.ellipse_points(b.pos, b.r / wobble, b.r * wobble * 1.2, 0.0, 0.0, TAU, 28)
		draw_colored_polygon(pts, Color(b.color, 0.75))
		draw_circle(b.pos + Vector2(-b.r * 0.3, -b.r * 0.4), b.r * 0.25, Color(1, 1, 1, 0.12))
	for p in _pops:
		var f: float = p.age / 0.6
		draw_arc(p.pos, p.r * (1.0 + f), 0.0, TAU, 32, Color(p.color, 1.0 - f), 6.0 * (1.0 - f) + 1.0, true)
