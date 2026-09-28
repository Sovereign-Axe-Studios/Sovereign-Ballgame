extends GameMod
## Wormholes -- a black hole and a white hole sit in empty cells. A ball that
## falls into the black hole comes out of the white hole with the same
## heading. One-way, like the Hourglass Twins' pair. They relocate every few
## rounds, and at once if a block shifts into either cell.
## Unlocked by the title-screen constellation.

## Capture distance from the black hole's centre, as a fraction of cell size.
const CAPTURE_FRACTION := 0.38
## How far past the white hole's centre a ball is placed on exit, as a
## fraction of cell size -- far enough that it can't be recaptured at once.
const EXIT_FRACTION := 0.45
## Seconds before the same ball can use the wormhole again.
const REENTRY_COOLDOWN := 0.3
## Rounds between relocations.
const RELOCATE_ROUNDS := 3

const NO_CELL := Vector2i(-1, -1)

var _field: Playfield
var _black := NO_CELL
var _white := NO_CELL
var _rounds_here: int = 0
var _visual: WormholeVisual
## Ball instance id -> msec it last came through.
var _last_trip: Dictionary = {}

func _init() -> void:
	category = Category.WALL
	display_name = "Wormholes"
	description = "A black hole sends balls out of a white hole. They move every %d rounds." % RELOCATE_ROUNDS
	locked_by = Unlocks.OUTER_WILDS

func on_run_start(_rules: GameRules, field: Playfield) -> void:
	_field = field
	if not is_instance_valid(_visual):
		_visual = WormholeVisual.new()
		field.effects_root.add_child(_visual)
	_relocate()

func on_round_end(_rules: GameRules, field: Playfield) -> void:
	_field = field
	_rounds_here += 1
	if _rounds_here >= RELOCATE_ROUNDS or _occupied(_black) or _occupied(_white):
		_relocate()

func on_ball_moved(_rules: GameRules, ball: Ball) -> void:
	if _field == null or _black == NO_CELL:
		return
	var cell := _field.grid.cell_size
	var hole := _field.grid.cell_center(_black.x, _black.y)
	if ball.global_position.distance_to(hole) > cell * CAPTURE_FRACTION:
		return
	var id := ball.get_instance_id()
	var now := Time.get_ticks_msec()
	if _last_trip.has(id) and now - int(_last_trip[id]) < int(REENTRY_COOLDOWN * 1000.0):
		return
	_last_trip[id] = now
	var exit := _field.grid.cell_center(_white.x, _white.y)
	ball.global_position = exit + ball.direction * cell * EXIT_FRACTION

func _occupied(c: Vector2i) -> bool:
	return c != NO_CELL and _field.grid.cells[c.y][c.x] != null

## Two different empty cells between row 1 and the row above the death row.
## Too few empty cells -> the wormholes close until the next relocation.
func _relocate() -> void:
	_rounds_here = 0
	var grid := _field.grid
	var empty: Array[Vector2i] = []
	for row in range(1, _field.rules.death_row()):
		for col in range(_field.rules.grid_width):
			if grid.cells[row][col] == null:
				empty.append(Vector2i(col, row))
	GameRules.shuffle(empty, _field.rules.field_rng)
	if empty.size() < 2:
		_black = NO_CELL
		_white = NO_CELL
	else:
		_black = empty[0]
		_white = empty[1]
	_visual.set_holes(
		grid.cell_center(_black.x, _black.y) if _black != NO_CELL else Vector2.INF,
		grid.cell_center(_white.x, _white.y) if _white != NO_CELL else Vector2.INF,
		grid.cell_size * CAPTURE_FRACTION)


## A ball dropping into the black hole and flying out of the white one.
func draw_preview(c: CanvasItem, r: Rect2, t: float) -> void:
	PreviewDraw.board(c, r)
	var black := PreviewDraw.at(r, 0.3, 0.62)
	var white := PreviewDraw.at(r, 0.7, 0.3)
	var s := PreviewDraw.px(r, 0.14)
	WormholeVisual.draw_black_hole(c, black, s, t)
	WormholeVisual.draw_white_hole(c, white, s, t)
	var p := PreviewDraw.phase(t, 2.0)
	var dir := Vector2(0.55, -1.0).normalized()
	var pos: Vector2
	if p < 0.5:
		pos = black - dir * PreviewDraw.px(r, 0.4) * (1.0 - p * 2.0)
	else:
		pos = white + dir * PreviewDraw.px(r, 0.45) * ((p - 0.5) * 2.0)
	PreviewDraw.ball(c, pos, PreviewDraw.px(r, 0.05))


## Draws both holes. Added under the field's effects root by on_run_start.
class WormholeVisual extends Node2D:
	var _black := Vector2.INF
	var _white := Vector2.INF
	var _radius: float = 30.0
	var _t: float = 0.0

	func set_holes(black: Vector2, white: Vector2, radius: float) -> void:
		_black = black
		_white = white
		_radius = radius
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if _black != Vector2.INF:
			draw_black_hole(self, _black, _radius, _t)
		if _white != Vector2.INF:
			draw_white_hole(self, _white, _radius, _t)

	## Dark core, a swirl of orange accretion arcs around it.
	static func draw_black_hole(c: CanvasItem, pos: Vector2, r: float, t: float) -> void:
		for i in range(3):
			var a := t * 2.5 + i * TAU / 3.0
			c.draw_arc(pos, r * (1.15 + i * 0.18), a, a + 2.2, 20, Color("#f08a3c", 0.75 - i * 0.2), 3.0)
		c.draw_circle(pos, r, Color("#05070a"))
		c.draw_arc(pos, r, 0.0, TAU, 32, Color("#f2c27a", 0.6), 1.5)

	## Bright core with slowly turning outward rays.
	static func draw_white_hole(c: CanvasItem, pos: Vector2, r: float, t: float) -> void:
		for i in range(8):
			var a := -t * 0.8 + i * TAU / 8.0
			var d := Vector2.RIGHT.rotated(a)
			c.draw_line(pos + d * r * 1.05, pos + d * r * 1.6, Color(1, 1, 1, 0.55), 2.0)
		c.draw_circle(pos, r, Color("#f5f7ff"))
		c.draw_circle(pos, r * 0.6, Color("#cfe3ff"))
