extends AnimatedBackground
## Aurora -- tall hanging curtains of light with vertical rays, filling most
## of the screen and swaying slowly.
## Board cleared: the curtains surge bright and shift hue.
## New ball: the curtain nearest the landing spot brightens.

const SKY := Color("#040a14")
const CURTAINS: Array[Color] = [Color("#50ffaa"), Color("#5aa0ff"), Color("#c86eff"), Color("#50ffd8")]
const RAY_STEP := 7.0
## Curtain height as a fraction of screen height.
const LENGTH := 0.55

var _surge: float = 0.0
var _hue_shift: float = 0.0
var _bright := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _stars := PackedVector2Array()

func _ready() -> void:
	super()
	for i in range(70):
		_stars.append(Vector2(randf() * view.x, randf() * view.y * 0.6))

func on_board_cleared(_pos: Vector2) -> void:
	_surge = 1.0
	_hue_shift += 0.15

func on_new_ball(pos: Vector2) -> void:
	var k := clampi(int(pos.x / view.x * CURTAINS.size()), 0, CURTAINS.size() - 1)
	_bright[k] = 1.0

func _process(delta: float) -> void:
	super(delta)
	_surge = maxf(0.0, _surge - delta * 0.5)
	for k in range(_bright.size()):
		_bright[k] = maxf(0.0, _bright[k] - delta * 0.8)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), SKY, true)
	for star in _stars:
		draw_circle(star, 1.4, Color(1, 1, 1, 0.35 + 0.25 * sin(t * 1.5 + star.x)))
	# Each curtain hangs from a wavy lower hem -- brightest there -- with rays
	# fading upward, like the real thing.
	for k in range(CURTAINS.size()):
		var base := CURTAINS[k]
		var col := Color.from_hsv(fposmod(base.h + _hue_shift, 1.0), base.s, 1.0)
		var hem0 := view.y * (0.42 + k * 0.09)
		var length := view.y * LENGTH * (0.75 + 0.25 * sin(t * 0.3 + k))
		var glow := 0.3 + 0.25 * _surge + 0.35 * _bright[k]
		var x := -40.0
		while x < view.x + 40.0:
			var hem := hem0 + sin(x * 0.005 + t * (0.3 + k * 0.07) + k * 1.3) * 110.0
			var lean := sin(x * 0.008 + t * 0.4 + k) * 40.0
			var ray := 0.55 + 0.45 * sin(x * 0.31 + t * 1.7 + k * 5.0)
			var a := glow * ray
			var top := hem - length * (0.7 + 0.3 * ray)
			draw_polygon(PackedVector2Array([
				Vector2(x + lean, top), Vector2(x + RAY_STEP + lean, top),
				Vector2(x + RAY_STEP, hem), Vector2(x, hem),
			]), PackedColorArray([Color(col, 0.0), Color(col, 0.0), Color(col, a), Color(col, a)]))
			# A short soft glow under the hem.
			draw_polygon(PackedVector2Array([
				Vector2(x, hem), Vector2(x + RAY_STEP, hem),
				Vector2(x + RAY_STEP, hem + 40.0), Vector2(x, hem + 40.0),
			]), PackedColorArray([Color(col, a * 0.6), Color(col, a * 0.6), Color(col, 0.0), Color(col, 0.0)]))
			x += RAY_STEP
