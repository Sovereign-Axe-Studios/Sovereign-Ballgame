class_name PreviewDraw
## Drawing helpers for GameMod.draw_preview sketches, so every mod's icon
## shares one look: a dark mini-board, the current ball/block skins, and
## coordinates given as fractions of the preview rect (u, v in 0..1).

const BG := Color("#0b1016")
const FRAME := Color("#2d4a45")
const ACCENT := Color("#b06fe8")
const GLOW := Color("#f4c0d1")

static func board(c: CanvasItem, r: Rect2) -> void:
	c.draw_rect(r, BG, true)
	c.draw_rect(r.grow(-1.0), FRAME, false, 2.0)

## Fraction-of-rect to canvas point.
static func at(r: Rect2, u: float, v: float) -> Vector2:
	return r.position + Vector2(u * r.size.x, v * r.size.y)

## Fraction-of-rect-width to pixels.
static func px(r: Rect2, f: float) -> float:
	return f * minf(r.size.x, r.size.y)

## The current ball look, or a flat disc of `color` if one is given.
static func ball(c: CanvasItem, pos: Vector2, radius: float, color: Color = Color.TRANSPARENT,
		spin: float = 0.0, t: float = 0.0) -> void:
	if color.a == 0.0:
		Skins.ball().draw(c, pos, radius, spin, t)
		return
	c.draw_circle(pos, radius, color)
	c.draw_circle(pos + Vector2(-radius, -radius) * 0.3, radius * 0.3, Color(1, 1, 1, 0.55))

## A block like Block._draw: fill, lighter outline, value label.
static func block(c: CanvasItem, center: Vector2, size: float, value: int,
		rotation_deg: float = 0.0, corner: float = 0.0) -> void:
	var color := Palette.health_color(value * 12)
	c.draw_set_transform(center, deg_to_rad(rotation_deg))
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = color.lightened(0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(corner * size * 0.5))
	sb.draw(c.get_canvas_item(), Rect2(Vector2.ONE * -size * 0.5, Vector2.ONE * size))
	c.draw_set_transform(center, 0.0)
	text(c, Vector2.ZERO, str(value), int(size * 0.4), Palette.label_color(color))
	c.draw_set_transform(Vector2.ZERO, 0.0)

## Centred text at `pos`.
static func text(c: CanvasItem, pos: Vector2, s: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	c.draw_string(font, pos + Vector2(-w * 0.5, font_size * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

## Looping 0..1 phase with period `seconds`.
static func phase(t: float, seconds: float) -> float:
	return fposmod(t, seconds) / seconds
