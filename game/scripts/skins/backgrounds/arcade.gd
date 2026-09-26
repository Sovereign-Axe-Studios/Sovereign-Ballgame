extends AnimatedBackground
## Arcade -- pixel invaders drifting across a scanlined screen.
## Board cleared: every invader bursts into pixels and STAGE CLEAR blinks.
## New ball: the nearest invader flashes 1UP and zips off.

const BG := Color("#050510")
const COLORS: Array[Color] = [Color("#4ff0ff"), Color("#ff4fd8"), Color("#7cf7c4")]
const SPRITE: Array[String] = ["00111000", "01111100", "11010110", "11111110", "01010100", "10000010"]
const PIXEL := 9.0
const COUNT := 14
const CLEAR_SECONDS := 2.5

var _invaders: Array[Dictionary] = []
var _bits: Array[Dictionary] = []
var _clear_left: float = 0.0

func _ready() -> void:
	super()
	for i in range(COUNT):
		_invaders.append(_new_invader())

func _new_invader() -> Dictionary:
	return {
		"pos": Vector2(randf() * view.x, randf_range(0.05, 0.95) * view.y),
		"vel": Vector2(randf_range(20.0, 50.0) * (1.0 if randf() < 0.5 else -1.0), 0.0),
		"color": COLORS[randi() % COLORS.size()],
		"oneup": 0.0,
	}

func on_board_cleared(_pos: Vector2) -> void:
	for inv in _invaders:
		for k in range(12):
			_bits.append({"pos": inv.pos, "vel": Vector2.RIGHT.rotated(randf() * TAU) * randf_range(80, 320),
				"color": inv.color, "life": 1.0})
	_invaders.clear()
	_clear_left = CLEAR_SECONDS

func on_new_ball(pos: Vector2) -> void:
	var best: Dictionary = {}
	var best_d := INF
	for inv in _invaders:
		var d: float = inv.pos.distance_to(pos)
		if d < best_d and inv.oneup <= 0.0:
			best_d = d
			best = inv
	if not best.is_empty():
		best.oneup = 1.2

func _process(delta: float) -> void:
	super(delta)
	if _clear_left > 0.0:
		_clear_left -= delta
		if _clear_left <= 0.0:
			for i in range(COUNT):
				_invaders.append(_new_invader())
	for inv in _invaders:
		if inv.oneup > 0.0:
			inv.oneup -= delta
			inv.pos += Vector2(0, -500.0) * delta
			if inv.oneup <= 0.0:
				inv.merge(_new_invader(), true)
		else:
			inv.pos += inv.vel * delta
			inv.pos.x = wrapf(inv.pos.x, -80.0, view.x + 80.0)
	for bit in _bits:
		bit.pos += bit.vel * delta
		bit.life -= delta
	_bits = _bits.filter(func(b: Dictionary) -> bool: return b.life > 0.0)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), BG, true)
	var frame := int(t * 2.0) % 2
	for inv in _invaders:
		for row in range(SPRITE.size()):
			for col in range(SPRITE[row].length()):
				if SPRITE[row][col] == "1":
					var p: Vector2 = inv.pos + Vector2(col, row + frame * 0.3) * PIXEL
					draw_rect(Rect2(p, Vector2.ONE * (PIXEL - 1.0)), Color(inv.color, 0.55), true)
		if inv.oneup > 0.0:
			PreviewDraw.text(self, inv.pos + Vector2(36, -24), "1UP", 34, Color.WHITE)
	for bit in _bits:
		draw_rect(Rect2(bit.pos, Vector2.ONE * PIXEL * 0.8), Color(bit.color, bit.life), true)
	if _clear_left > 0.0 and int(_clear_left * 4.0) % 2 == 0:
		PreviewDraw.text(self, view * Vector2(0.5, 0.45), "STAGE CLEAR", 90, Color("#f2c94c"))
	for y in range(0, int(view.y), 4):
		draw_line(Vector2(0, y), Vector2(view.x, y), Color(0, 0, 0, 0.35), 1.0)
