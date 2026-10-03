class_name BallLook
extends SkinRecord
## How a ball is drawn. One file per look under scripts/skins/balls/, each
## `extends BallLook` and overriding `draw`; registered by a preload line in
## Skins.BALL_LOOKS. The base class is a flat disc with a highlight -- the
## basic colours are just instances of it.
##
## Every ball-shaped thing draws through here (Ball, FallingBall, the menu
## swatches, PreviewDraw), so a look only has to be written once.

## Accent colour for menus, the launcher and aim dots.
var color := Color.WHITE
var highlight := Color(1, 1, 1, 0.55)
## A tail behind a moving Ball (drawn by Ball from its position history).
## TRANSPARENT = no tail.
var trail_color := Color.TRANSPARENT
## Chance per frame of a fleck (ember, flake, ghost matter) in the tail.
var fleck_chance: float = 0.0
var fleck_color := Color.WHITE

func _init(n: String = "", c: Color = Color.WHITE) -> void:
	skin_name = n
	color = c

## Draw at `pos` with radius `r`. `spin` is how far the ball has rolled
## (radians, from distance travelled / radius) -- rotate surface detail by it
## so looks roll with motion; keep lighting (highlights, rims) unrotated.
## `t` is seconds, for animated details.
func draw(c: CanvasItem, pos: Vector2, r: float, _spin: float, _t: float) -> void:
	c.draw_circle(pos, r, color)
	c.draw_circle(pos + Vector2(-r, -r) * 0.3, r * 0.3, highlight)

## `color`, lightened until it reads on a dark board -- for the aim dots and
## the launcher's ammo count, which a Charcoal or Purple ball would otherwise
## all but hide. Ball colours are earned cosmetics, so none may cost aim.
func ui_color() -> Color:
	var out := color
	for i in range(8):
		if out.get_luminance() >= UI_MIN_LUMINANCE:
			break
		out = out.lightened(0.2)
	return out

## Floor for ui_color(). Roughly where a colour clears 7:1 on the background.
const UI_MIN_LUMINANCE := 0.55
## The in-play contrast ring: dark inner band (reads on bright blocks),
## light outer band (reads on the dark board).
const RING_DARK := Color(0.03, 0.04, 0.06, 0.9)
const RING_LIGHT := Color(1, 1, 1, 0.6)

## Two-tone ring just outside the ball, drawn for every look in play so a
## ball stays visible whatever block or background it is over -- a red ball
## over a red block otherwise vanishes (playtest 10/01 colour pass).
static func contrast_ring(c: CanvasItem, pos: Vector2, r: float) -> void:
	c.draw_arc(pos, r + 1.0, 0.0, TAU, 40, RING_DARK, 2.0, true)
	c.draw_arc(pos, r + 2.75, 0.0, TAU, 40, RING_LIGHT, 1.5, true)


# ------------------------------------------------------------------ helpers
# Canvas drawing has no clip-to-circle, so these build shapes that already
# fit inside the ball.

## Soft top-left light and a darker rim, over whatever was drawn.
static func shade(c: CanvasItem, pos: Vector2, r: float, light: float = 0.45, rim: float = 0.3) -> void:
	# Graded, not one band: a single dark ring reads as an outline.
	for i in range(4):
		var f := i / 4.0
		c.draw_arc(pos, r * (0.97 - f * 0.1), 0.0, TAU, 40, Color(0, 0, 0, rim * 0.35 * (1.0 - f)), r * 0.06, true)
	c.draw_circle(pos + Vector2(-r, -r) * 0.32, r * 0.26, Color(1, 1, 1, light))
	c.draw_circle(pos + Vector2(-r, -r) * 0.38, r * 0.12, Color(1, 1, 1, light * 0.9))

## A pie wedge from angle a0 to a1.
static func wedge(c: CanvasItem, pos: Vector2, r: float, a0: float, a1: float, col: Color) -> void:
	var pts := PackedVector2Array([pos])
	for i in range(9):
		var a := lerpf(a0, a1, i / 8.0)
		pts.append(pos + Vector2(cos(a), sin(a)) * r)
	c.draw_colored_polygon(pts, col)

## The part of the circle between local y0 and y1 (y0 < y1), rotated by `rot`
## -- a horizontal band on a sphere.
static func band(c: CanvasItem, pos: Vector2, r: float, y0: float, y1: float, rot: float, col: Color) -> void:
	y0 = clampf(y0, -r, r)
	y1 = clampf(y1, -r, r)
	if y1 <= y0:
		return
	var pts := PackedVector2Array()
	var steps := 8
	for i in range(steps + 1):
		var y := lerpf(y0, y1, i / float(steps))
		pts.append(pos + Vector2(sqrt(maxf(0.0, r * r - y * y)), y).rotated(rot))
	for i in range(steps, -1, -1):
		var y := lerpf(y0, y1, i / float(steps))
		pts.append(pos + Vector2(-sqrt(maxf(0.0, r * r - y * y)), y).rotated(rot))
	c.draw_colored_polygon(pts, col)

## Polyline of points `pts` (local, unrotated, relative to the centre),
## rotated by `rot`, dropping any segment that leaves the circle.
static func inside_line(c: CanvasItem, pos: Vector2, r: float, pts: PackedVector2Array, rot: float,
		col: Color, width: float) -> void:
	for i in range(pts.size() - 1):
		if pts[i].length() <= r and pts[i + 1].length() <= r:
			c.draw_line(pos + pts[i].rotated(rot), pos + pts[i + 1].rotated(rot), col, width, true)

static func ellipse_points(center: Vector2, rx: float, ry: float, rot: float, a0: float, a1: float,
		steps: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var a := lerpf(a0, a1, i / float(steps))
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts
