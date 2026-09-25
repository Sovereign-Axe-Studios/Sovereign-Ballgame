class_name EndTimesBackground
extends Node2D
## The End Times background skin: a starfield living through the end of the
## universe on a loop. Stars blink out one by one, some going supernova on
## the way; once the last one is gone there's a big-bang flash from the
## centre, a fresh set streams outward and settles, and it starts over.
##
## Game adds this (show_behind_parent) while the active background skin is
## `animated`, and skips its own flat fill, so walls and blocks draw on top.

const STAR_COUNT := 80
## One full cycle: death, darkness, big bang, new stars settling.
const CYCLE_SECONDS := 60.0
## Share of stars that go supernova before dying.
const SUPERNOVA_CHANCE := 1.0 / 6.0
const BG_COLOR := Color("#06080c")
const STAR_COLOR := Color("#e8eefc")
const NOVA_COLOR := Color("#ffd27a")

# Cycle phases, as fractions of CYCLE_SECONDS.
const DEATHS_START := 0.05
const DEATHS_END := 0.8
const BANG_AT := 0.86
const BANG_LENGTH := 0.04
const SETTLE_START := 0.88
## A supernova flares for this share of the cycle before its star dies, and
## its ring spreads for the same again after.
const NOVA_LENGTH := 0.03

var _view := Vector2.ZERO
var _t: float = 0.0
var _cycle: int = -1
var _rest := PackedVector2Array()      ## where this cycle's stars sit
var _next_rest := PackedVector2Array() ## where the next cycle's will settle
var _death := PackedFloat32Array()
var _nova: Array[bool] = []
var _size := PackedFloat32Array()

func _ready() -> void:
	show_behind_parent = true
	_view = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	_next_rest = _random_positions()
	_start_cycle(0)

func _process(delta: float) -> void:
	_t += delta
	var cycle := int(_t / CYCLE_SECONDS)
	if cycle != _cycle:
		_start_cycle(cycle)
	queue_redraw()

func _start_cycle(cycle: int) -> void:
	_cycle = cycle
	_rest = _next_rest
	_next_rest = _random_positions()
	_death.resize(STAR_COUNT)
	_size.resize(STAR_COUNT)
	_nova.clear()
	for i in range(STAR_COUNT):
		_death[i] = randf_range(DEATHS_START, DEATHS_END)
		_size[i] = randf_range(1.0, 2.6)
		_nova.append(randf() < SUPERNOVA_CHANCE)

func _random_positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(STAR_COUNT):
		out.append(Vector2(randf() * _view.x, randf() * _view.y))
	return out

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _view), BG_COLOR, true)
	var p := fposmod(_t, CYCLE_SECONDS) / CYCLE_SECONDS
	var center := _view * 0.5

	if p < SETTLE_START:
		for i in range(STAR_COUNT):
			_draw_dying_star(i, p)
	else:
		# New stars streaming out from the centre and easing into place.
		var f := ease((p - SETTLE_START) / (1.0 - SETTLE_START), 0.3)
		for i in range(STAR_COUNT):
			var pos := center.lerp(_next_rest[i], f)
			draw_circle(pos, _size[i], Color(STAR_COLOR, 0.3 + 0.6 * f))

	if p >= BANG_AT and p < BANG_AT + BANG_LENGTH * 2.0:
		var b := (p - BANG_AT) / (BANG_LENGTH * 2.0)
		var radius := _view.length() * b
		draw_circle(center, radius, Color(1, 1, 1, (1.0 - b) * 0.9))

func _draw_dying_star(i: int, p: float) -> void:
	var pos := _rest[i]
	var death := _death[i]
	if _nova[i]:
		if p >= death - NOVA_LENGTH and p < death:
			# Flaring up before it blows.
			var f := (p - (death - NOVA_LENGTH)) / NOVA_LENGTH
			draw_circle(pos, _size[i] * (1.0 + f * 5.0), Color(NOVA_COLOR, 0.6 + 0.4 * f))
			return
		if p >= death and p < death + NOVA_LENGTH:
			var f := (p - death) / NOVA_LENGTH
			draw_arc(pos, 8.0 + f * 90.0, 0.0, TAU, 32, Color(NOVA_COLOR, 1.0 - f), 3.0)
			return
	if p >= death:
		return
	var twinkle := 0.5 + 0.35 * sin(_t * 1.3 + float(i) * 1.7)
	draw_circle(pos, _size[i], Color(STAR_COLOR, twinkle))
