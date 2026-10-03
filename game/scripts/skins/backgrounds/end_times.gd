class_name EndTimesBackground
extends AnimatedBackground
## The End Times background skin: a starfield living through the end of the
## universe on a loop. Stars blink out one by one, each going supernova on
## the way; once the last one is gone there's a big-bang flash from the
## centre, a fresh set streams outward and settles, and it starts over.
##
## Board cleared: an instant big bang. New ball: the nearest living star goes
## supernova. Unlocked by the title-screen constellation.

const STAR_COUNT := 80
## Share of stars that go supernova before dying: all of them.
const SUPERNOVA_CHANCE := 1.0
const BG_COLOR := Color("#06080c")
const STAR_COLOR := Color("#e8eefc")
const NOVA_COLOR := Color("#ffd27a")

# Cycle phases, in seconds from the start of a cycle. Seconds, not fractions
# of the cycle: the deaths are the slow part, and stretching the cycle must
# not slow the flares and the bang down with it.
## The big bang: 22 minutes in. Every star has burst before it.
const BANG_AT := 1320.0
const DEATHS_START := 3.0
## A beat of total darkness between the last star and the bang.
const DEATHS_END := BANG_AT - 3.6
## The bang's flash spreads for twice this.
const BANG_LENGTH := 2.4
const SETTLE_START := BANG_AT + 1.2
const SETTLE_LENGTH := 7.2
## One full cycle: deaths, darkness, big bang, new stars settling.
const CYCLE_SECONDS := SETTLE_START + SETTLE_LENGTH
## A supernova flares for this long before its star dies, and its ring
## spreads for the same again after.
const NOVA_LENGTH := 1.8

var _cycle: int = -1
var _rest := PackedVector2Array()      ## where this cycle's stars sit
var _next_rest := PackedVector2Array() ## where the next cycle's will settle
var _death := PackedFloat32Array()
var _nova: Array[bool] = []
var _size := PackedFloat32Array()

func _ready() -> void:
	super()
	_next_rest = _random_positions()
	_start_cycle(0)

func _process(delta: float) -> void:
	super(delta)
	var cycle := int(t / CYCLE_SECONDS)
	if cycle != _cycle:
		_start_cycle(cycle)

## Skip straight to this cycle's big bang.
func on_board_cleared(_pos: Vector2) -> void:
	t = float(_cycle) * CYCLE_SECONDS + BANG_AT

## The nearest star still alive goes supernova right now.
func on_new_ball(pos: Vector2) -> void:
	var p := fposmod(t, CYCLE_SECONDS)
	if p >= DEATHS_END:
		return
	var best := -1
	var best_d := INF
	for i in range(STAR_COUNT):
		if p < _death[i] - NOVA_LENGTH and _rest[i].distance_to(pos) < best_d:
			best_d = _rest[i].distance_to(pos)
			best = i
	if best >= 0:
		_nova[best] = true
		_death[best] = p + NOVA_LENGTH

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
		out.append(Vector2(randf() * view.x, randf() * view.y))
	return out

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), BG_COLOR, true)
	var p := fposmod(t, CYCLE_SECONDS)
	var center := view * 0.5

	if p < SETTLE_START:
		for i in range(STAR_COUNT):
			_draw_dying_star(i, p)
	else:
		# New stars streaming out from the centre and easing into place.
		var f := ease(clampf((p - SETTLE_START) / SETTLE_LENGTH, 0.0, 1.0), 0.3)
		for i in range(STAR_COUNT):
			var pos := center.lerp(_next_rest[i], f)
			draw_circle(pos, _size[i], Color(STAR_COLOR, 0.3 + 0.6 * f))

	if p >= BANG_AT and p < BANG_AT + BANG_LENGTH * 2.0:
		var b := (p - BANG_AT) / (BANG_LENGTH * 2.0)
		# A glowing burst: soft layered falloff and a bright shock ring,
		# not a flat disc.
		var radius := view.length() * b
		for i in range(6):
			var f := 1.0 - i / 6.0
			draw_circle(center, radius * f, Color(1.0, 0.9, 0.7, (1.0 - b) * 0.22))
		draw_circle(center, radius * 0.12, Color(1, 1, 1, 1.0 - b))
		draw_arc(center, radius, 0.0, TAU, 64, Color(1.0, 0.9, 0.7, (1.0 - b) * 0.9), 10.0 * (1.0 - b) + 2.0, true)

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
	var twinkle := 0.5 + 0.35 * sin(t * 1.3 + float(i) * 1.7)
	draw_circle(pos, _size[i], Color(STAR_COLOR, twinkle))
