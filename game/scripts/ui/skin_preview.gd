class_name SkinPreview
extends VBoxContainer
## The Asset Viewer's live look at the current skins: the ball look rolling
## back and forth across a strip, and a BackgroundPreview with buttons that
## fire its board-cleared / new-ball reactions. It shows whichever background
## `show_background` was last given -- the Asset Viewer feeds it SkinsPanel's
## hover, so the big preview follows the mouse over the chips.

## The background renders at full screen size and is shown scaled.
const BG_SCALE := 0.42
const STRIP_HEIGHT := 150.0
const BALL_RADIUS := 44.0

var _strip: Control
var _t: float = 0.0
var _bg_preview: BackgroundPreview
var _clear_btn: Button
var _new_btn: Button

func _init() -> void:
	add_theme_constant_override("separation", 18)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var view := NeonUI.view_size()

	add_child(NeonUI.subheader("Ball"))
	_strip = Control.new()
	_strip.custom_minimum_size = Vector2(0.0, STRIP_HEIGHT)
	_strip.draw.connect(_draw_strip)
	add_child(_strip)

	add_child(NeonUI.subheader("Background"))
	_bg_preview = BackgroundPreview.new(BG_SCALE)
	add_child(_bg_preview)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_clear_btn = NeonUI.button("BOARD CLEARED")
	_clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clear_btn.pressed.connect(func() -> void:
		var bg := _bg_preview.current()
		if bg != null:
			bg.on_board_cleared(view * 0.5))
	row.add_child(_clear_btn)
	_new_btn = NeonUI.button("NEW BALL")
	_new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_btn.pressed.connect(func() -> void:
		var bg := _bg_preview.current()
		if bg != null:
			bg.on_new_ball(Vector2(randf_range(0.15, 0.85) * view.x, randf_range(0.3, 0.9) * view.y)))
	row.add_child(_new_btn)
	add_child(row)

func _ready() -> void:
	show_background(Skins.background())

func _process(delta: float) -> void:
	_t += delta
	_strip.queue_redraw()

## Show `skin` (hovered or selected); the reaction buttons follow it.
func show_background(skin: Skins.BackgroundSkin) -> void:
	_bg_preview.show_skin(skin)
	var reacts := skin.scene != null
	for b in [_clear_btn, _new_btn]:
		b.disabled = not reacts
		b.tooltip_text = "" if reacts else "Flat backgrounds have no reactions."

## The current ball look rolling back and forth; spin follows distance.
func _draw_strip() -> void:
	var w := _strip.size.x
	_strip.draw_rect(Rect2(Vector2.ZERO, _strip.size), Color(0.02, 0.02, 0.05, 0.8), true)
	_strip.draw_line(Vector2(0, STRIP_HEIGHT - 20.0), Vector2(w, STRIP_HEIGHT - 20.0), Color(NeonUI.CYAN, 0.4), 2.0)
	var travel := w - BALL_RADIUS * 2.0 - 40.0
	var x := BALL_RADIUS + 20.0 + (sin(_t * 0.9) * 0.5 + 0.5) * travel
	var pos := Vector2(x, STRIP_HEIGHT - 20.0 - BALL_RADIUS)
	PreviewDraw.ball(_strip, pos, BALL_RADIUS, Color.TRANSPARENT, x / BALL_RADIUS, _t)
