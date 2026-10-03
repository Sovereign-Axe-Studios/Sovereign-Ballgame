class_name DesignationLine
extends HBoxContainer
## The title screen's build designation -- "—— SERVICE MODE // DEBUG BUILD ——"
## -- drawn in like a cabinet booting: the two rules extend outward from the
## text, then the line types itself out behind a block cursor, which stays
## blinking once it's done.
##
## The Label always holds the full text and reveals it through
## visible_characters, so the row is laid out at its final width from the
## first frame: nothing shifts while it types. The rules grow by scale for the
## same reason -- scale doesn't touch layout, a growing min size would.

const FONT_SIZE := 22
const TRACKING := 6
const RULE_WIDTH := 120.0
## Wide enough that the cursor, which sits just past the text, clears the rule.
const GAP := 30
const START_DELAY := 0.25
const RULE_SECONDS := 0.35
const CHAR_SECONDS := 0.04
## Held a beat on each separator, the way a typist stops at punctuation.
const SEPARATOR_PAUSE := 0.18
const CURSOR_SIZE := Vector2(11.0, 20.0)
const CURSOR_GAP := 4.0
const BLINK_SECONDS := 0.5

var _label: Label
var _cursor: ColorRect
var _left_rule: ColorRect
var _right_rule: ColorRect
var _font: Font
## Seconds after the rules finish at which character i appears; built once so
## the per-frame reveal is a lookup, not a re-walk of the pauses.
var _char_times: PackedFloat32Array = []
var _t: float = 0.0

func _init(text: String, color: Color) -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", GAP)

	_label = NeonUI.label(text, FONT_SIZE, color)
	# One line at its natural width, so the rules hug it: NeonUI.label wraps
	# and expands, which would push them out to the screen edges.
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tracked := FontVariation.new()
	tracked.base_font = _label.get_theme_font("font")
	tracked.spacing_glyph = TRACKING
	_label.add_theme_font_override("font", tracked)
	# After shaping, so hidden characters still take up their room; the
	# default trims before shaping and the row would grow as it types.
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_label.visible_characters = 0
	_font = tracked

	_cursor = ColorRect.new()
	_cursor.color = color
	_cursor.size = CURSOR_SIZE
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.visible = false
	_label.add_child(_cursor)

	# Each rule grows away from the text, so its pivot is its inner end.
	_left_rule = _rule(color, Vector2(RULE_WIDTH, 1.0))
	_right_rule = _rule(color, Vector2(0.0, 1.0))
	add_child(_left_rule)
	add_child(_label)
	add_child(_right_rule)

	var at := 0.0
	for c in text:
		at += CHAR_SECONDS
		if c == "/":
			at += SEPARATOR_PAUSE * 0.5
		_char_times.append(at)

func _rule(color: Color, pivot: Vector2) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(color, 0.6)
	rule.custom_minimum_size = Vector2(RULE_WIDTH, 2.0)
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.pivot_offset = pivot
	rule.scale = Vector2(0.0, 1.0)
	return rule

func _process(delta: float) -> void:
	_t += delta
	var since := _t - START_DELAY
	if since < 0.0:
		return

	var grow := ease(clampf(since / RULE_SECONDS, 0.0, 1.0), 0.3)
	_left_rule.scale.x = grow
	_right_rule.scale.x = grow

	var typing := since - RULE_SECONDS
	if typing < 0.0:
		return
	var shown := _char_times.bsearch(typing, false)
	_label.visible_characters = shown
	var done := shown >= _char_times.size()
	# Solid while typing, a terminal blink once the line is in.
	_cursor.visible = not done or fmod(typing - _char_times[-1], BLINK_SECONDS * 2.0) < BLINK_SECONDS
	var typed := _label.text.left(shown)
	var x := _font.get_string_size(typed, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	_cursor.position = Vector2(x + CURSOR_GAP, (_label.size.y - CURSOR_SIZE.y) * 0.5)
