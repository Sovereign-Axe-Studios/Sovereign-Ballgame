extends AnimatedBackground
## Mosaic -- tiles shimmering in slow diagonal waves.
## Board cleared: a bright colour wave radiates from the last block.
## New ball: a small tile ripple spreads from where the ball landed.

const TILE := 60.0
const WAVE_SPEED := 900.0   ## px/s for event ripples

var _ripples: Array[Dictionary] = []  ## {pos, age, strength, reach}

func on_board_cleared(pos: Vector2) -> void:
	_ripples.append({"pos": pos, "age": 0.0, "strength": 1.0, "reach": 2400.0})

func on_new_ball(pos: Vector2) -> void:
	_ripples.append({"pos": pos, "age": 0.0, "strength": 0.6, "reach": 380.0})

func _process(delta: float) -> void:
	super(delta)
	for rp in _ripples:
		rp.age += delta
	_ripples = _ripples.filter(func(rp: Dictionary) -> bool: return rp.age * WAVE_SPEED < rp.reach + 200.0)

func _draw() -> void:
	var y := 0.0
	while y < view.y:
		var x := 0.0
		while x < view.x:
			var center := Vector2(x, y) + Vector2.ONE * TILE * 0.5
			var f := sin(t * 1.5 - (x + y) * 0.004) * 0.5 + 0.5
			var boost := 0.0
			for rp in _ripples:
				var front: float = rp.age * WAVE_SPEED
				var d: float = center.distance_to(rp.pos)
				if d < rp.reach:
					boost += maxf(0.0, 1.0 - absf(d - front) / 120.0) * rp.strength
			var hue := fposmod(0.58 + f * 0.17 + boost * 0.3, 1.0)
			var col := Color.from_hsv(hue, 0.55, 0.14 + f * 0.14 + boost * 0.5)
			draw_rect(Rect2(Vector2(x, y) + Vector2.ONE * 2.0, Vector2.ONE * (TILE - 4.0)), col, true)
			x += TILE
		y += TILE
