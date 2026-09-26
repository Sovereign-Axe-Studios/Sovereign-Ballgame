class_name NeonUI
## The neon geometric look shared by every menu: near-black violet ground,
## cyan and magenta accents, slanted buttons with a soft glow. Static builders
## only -- every screen composes these rather than styling controls itself,
## so the look lives in one file.
##
## `page()` is the one sanctioned way to build a scrolling menu page: it has
## the ScrollContainer child set to expand, so a page can never collapse to
## its minimum width again (the bug the old pause menu had).

const BG := Color("#07060f")
const PANEL := Color(0.05, 0.04, 0.12, 0.92)
const CYAN := Color("#4ff0ff")
const MAGENTA := Color("#ff4fd8")
const TEXT := Color("#f2efff")
const TEXT_SOFT := Color("#c9b8ff")
const TEXT_DIM := Color("#7d74a8")

const BUTTON_HEIGHT := 84.0
const BUTTON_FONT := 32
const CHIP_HEIGHT := 60.0
const CHIP_FONT := 24
const HEADER_FONT := 56
const SUBHEADER_FONT := 30
const LABEL_FONT := 24
## Horizontal slant of buttons, as StyleBoxFlat.skew.x.
const SKEW := 0.22
## Padding inside a scrolling page so slanted buttons' overhang isn't clipped.
const EDGE_PAD := 20


# ------------------------------------------------------------------ styles

## A slanted neon box. `lit` = hover/selected: brighter border, tinted fill,
## bigger glow.
static func box(lit: bool, accent: Color = CYAN, slant: float = SKEW) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent, 0.18) if lit else Color(0.04, 0.035, 0.1, 0.85)
	sb.border_color = accent if lit else Color(MAGENTA, 0.65)
	sb.set_border_width_all(3 if lit else 2)
	sb.skew = Vector2(slant, 0.0)
	sb.shadow_color = Color(accent, 0.45 if lit else 0.18)
	sb.shadow_size = 14 if lit else 6
	sb.content_margin_left = 30.0
	sb.content_margin_right = 30.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb

static func disabled_box() -> StyleBoxFlat:
	var sb := box(false)
	sb.border_color = Color(TEXT_DIM, 0.4)
	sb.shadow_size = 0
	sb.bg_color = Color(0.03, 0.03, 0.06, 0.8)
	return sb

## Panels: unslanted, cyan border, glow.
static func panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = Color(CYAN, 0.8)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(CYAN, 0.2)
	sb.shadow_size = 24
	sb.set_content_margin_all(40.0)
	return sb


# ---------------------------------------------------------------- controls

static func button(text: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	b.add_theme_font_size_override("font_size", BUTTON_FONT)
	var accent := MAGENTA if primary else CYAN
	b.add_theme_stylebox_override("normal", box(primary, accent))
	b.add_theme_stylebox_override("hover", box(true, accent))
	b.add_theme_stylebox_override("pressed", box(true, accent))
	b.add_theme_stylebox_override("hover_pressed", box(true, accent))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", disabled_box())
	b.add_theme_color_override("font_color", TEXT if primary else TEXT_SOFT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_hover_pressed_color", TEXT)
	b.add_theme_color_override("font_disabled_color", TEXT_DIM)
	return b

## A big on/off button (stands in for a checkbox, whose glyph doesn't scale).
## On = cyan lit.
static func toggle(text: String) -> Button:
	var b := button(text)
	b.toggle_mode = true
	b.add_theme_stylebox_override("pressed", box(true, CYAN))
	return b

## Compact radio option for a row of choices; group it with a ButtonGroup.
## `slant` 0 for square tiles that hold a drawn icon.
static func chip(text: String, slant: float = SKEW * 0.6) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0.0, CHIP_HEIGHT)
	b.add_theme_font_size_override("font_size", CHIP_FONT)
	var normal := box(false, CYAN, slant)
	normal.set_content_margin_all(10.0)
	normal.content_margin_left = 20.0
	normal.content_margin_right = 20.0
	var lit := box(true, CYAN, slant)
	lit.set_content_margin_all(10.0)
	lit.content_margin_left = 20.0
	lit.content_margin_right = 20.0
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("pressed", lit)
	b.add_theme_stylebox_override("hover_pressed", lit)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var dis := disabled_box()
	dis.skew = Vector2(slant, 0.0)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_color_override("font_color", TEXT_SOFT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_disabled_color", TEXT_DIM)
	return b

static func label(text: String, font_size: int = LABEL_FONT, color: Color = TEXT_SOFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Autowrap labels have no minimum width; in a Box they must expand or
	# they collapse to one character per line.
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

## Caps title with a short magenta bar under it.
static func header(text: String, font_size: int = HEADER_FONT) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var l := label(text.to_upper(), font_size, CYAN)
	l.add_theme_color_override("font_outline_color", Color(CYAN, 0.25))
	l.add_theme_constant_override("outline_size", 6)
	v.add_child(l)
	var bar := ColorRect.new()
	bar.color = MAGENTA
	bar.custom_minimum_size = Vector2(140.0, 4.0)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(bar)
	return v

static func subheader(text: String) -> Label:
	return label(text.to_upper(), SUBHEADER_FONT, CYAN)

static func slider(lo: float, hi: float, step: float = 1.0) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(0.0, 44.0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := StyleBoxFlat.new()
	track.bg_color = Color(MAGENTA, 0.25)
	track.content_margin_top = 4.0
	track.content_margin_bottom = 4.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = CYAN
	fill.content_margin_top = 4.0
	fill.content_margin_bottom = 4.0
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	return s

## Caption + slider stacked; returns the slider.
static func slider_row(col: Container, caption: String, lo: float, hi: float, step: float = 1.0) -> HSlider:
	col.add_child(label(caption))
	var s := slider(lo, hi, step)
	col.add_child(s)
	return s

## Dropdown with its popup (its own window, own tiny default theme) styled too.
static func option_button() -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	o.add_theme_font_size_override("font_size", LABEL_FONT)
	o.add_theme_stylebox_override("normal", box(false, CYAN, 0.0))
	o.add_theme_stylebox_override("hover", box(true, CYAN, 0.0))
	o.add_theme_stylebox_override("pressed", box(true, CYAN, 0.0))
	o.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	o.add_theme_color_override("font_color", TEXT)
	var popup := o.get_popup()
	popup.add_theme_font_size_override("font_size", BUTTON_FONT)
	popup.add_theme_constant_override("v_separation", 18)
	popup.add_theme_constant_override("item_start_padding", 18)
	popup.add_theme_constant_override("item_end_padding", 18)
	var pbg := panel_style()
	pbg.set_content_margin_all(10.0)
	popup.add_theme_stylebox_override("panel", pbg)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(CYAN, 0.2)
	popup.add_theme_stylebox_override("hover", hover)
	popup.add_theme_color_override("font_color", TEXT_SOFT)
	popup.add_theme_color_override("font_hover_color", TEXT)
	return o

static func spin_box(lo: int, hi: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.custom_minimum_size = Vector2(150.0, 60.0)
	var edit := s.get_line_edit()
	edit.add_theme_font_size_override("font_size", LABEL_FONT)
	edit.add_theme_color_override("font_color", TEXT)
	var sb := box(false, CYAN, 0.0)
	sb.set_content_margin_all(8.0)
	edit.add_theme_stylebox_override("normal", sb)
	return s

## Caption above a control.
static func captioned(control: Control, caption: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_child(label(caption, 20, TEXT_DIM))
	v.add_child(control)
	return v


# ------------------------------------------------------------------- pages

## A scrolling page: [scroll, column]. The scroll fills its parent; the
## column is centred at `width` (or fills, if width <= 0) with `margin` all
## round. Add content to the column.
static func page(width: float = 0.0, margin: int = 40) -> Array:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var center := MarginContainer.new()
	# The ScrollContainer only widens its child if the child asks to expand.
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# EDGE_PAD on top of `margin`: slanted boxes and their glow overhang their
	# rect, and the ScrollContainer clips anything past its edge.
	for side in ["left", "right", "top", "bottom"]:
		center.add_theme_constant_override("margin_%s" % side, margin + EDGE_PAD)
	scroll.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	if width > 0.0:
		col.custom_minimum_size = Vector2(width, 0.0)
		col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(col)
	return [scroll, col]

## Full-screen dim (skipped at dim_alpha 0) + a centred neon panel of `size`;
## returns [overlay, panel]. The overlay stops clicks reaching what's under it.
static func modal(parent: Node, size: Vector2, view: Vector2, dim_alpha: float = 0.7) -> Array:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)
	if dim_alpha > 0.0:
		var dim := ColorRect.new()
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.color = Color(0, 0, 0, dim_alpha)
		overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style())
	panel.position = (view - size) * 0.5
	panel.size = size
	panel.custom_minimum_size = size
	overlay.add_child(panel)
	return [overlay, panel]

static func view_size() -> Vector2:
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")))
