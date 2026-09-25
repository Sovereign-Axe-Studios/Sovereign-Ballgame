class_name ArcadeUI
## The title-screen look -- sharp corners, a neon border in the ball skin's
## colour -- shared by the title screen and Mode Select. Deliberately distinct
## from the pause menu's rounded style, so the front-end screens read as their
## own place.

const BUTTON_HEIGHT := 92.0
const BUTTON_FONT_SIZE := 34
const CHIP_HEIGHT := 60.0
const CHIP_FONT_SIZE := 26

static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	b.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	_apply(b)
	return b

## Toggle-mode, compact: one option in a row of chips. Lit = selected.
static func chip(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0.0, CHIP_HEIGHT)
	b.add_theme_font_size_override("font_size", CHIP_FONT_SIZE)
	_apply(b)
	b.add_theme_stylebox_override("hover_pressed", style(true))
	return b

static func style(lit: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#12313a") if lit else Color("#0e1a20")
	sb.border_color = Skins.ball().color
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	return sb

static func disabled_style() -> StyleBoxFlat:
	var sb := style(false)
	sb.border_color = Palette.TEXT_DIM
	sb.bg_color = Color("#0a0d12")
	return sb

static func label(text: String, font_size: int, color: Color = Palette.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func _apply(b: Button) -> void:
	b.add_theme_stylebox_override("normal", style(false))
	b.add_theme_stylebox_override("hover", style(true))
	b.add_theme_stylebox_override("pressed", style(true))
	b.add_theme_stylebox_override("disabled", disabled_style())
	b.add_theme_color_override("font_color", Skins.ball().color)
	b.add_theme_color_override("font_pressed_color", Palette.TEXT)
	b.add_theme_color_override("font_disabled_color", Palette.TEXT_DIM)
