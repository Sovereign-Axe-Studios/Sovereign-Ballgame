class_name BlockRampPreview
extends Control
## A small wall of bricks showing how a block skin colours the field: values
## from 1 up to 100 (the top of the ramp), each brick drawn the way Block
## draws itself, so you see the whole ramp as it reads in play. SkinsPanel
## shows the hovered skin, falling back to the selected one.

## Brick values, low to high, filled row by row.
const VALUES: Array[int] = [1, 4, 8, 12, 18, 25, 33, 42, 52, 64, 80, 100]
const COLS := 3
const CELL := 72.0
const GAP := 6.0

var _skin: Skins.BlockSkin

func _init() -> void:
	var rows := ceili(float(VALUES.size()) / COLS)
	custom_minimum_size = Vector2(COLS * CELL + (COLS - 1) * GAP, rows * CELL + (rows - 1) * GAP)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_skin(skin: Skins.BlockSkin) -> void:
	_skin = skin
	queue_redraw()

func _draw() -> void:
	if _skin == null:
		return
	var font := ThemeDB.fallback_font
	for i in range(VALUES.size()):
		var v := VALUES[i]
		var pos := Vector2((i % COLS) * (CELL + GAP), (i / COLS) * (CELL + GAP))
		var inset := CELL * Block.INSET_FRACTION
		var r := Rect2(pos + Vector2.ONE * inset, Vector2.ONE * (CELL - inset * 2.0))
		var color := Palette.ramp_color(_skin.ramp, v)
		draw_rect(r, color, true)
		draw_rect(r, color.lightened(0.25), false, 2.0)
		var text := str(v)
		var size := int(CELL * 0.3)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, r.get_center() + Vector2(-w * 0.5, size * 0.35), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, Palette.label_color(color))
