class_name SkinPreview
extends VBoxContainer
## The Asset Viewer's live look at the current skins: the ball look rolling
## back and forth across a strip, and the real background node running in a
## scaled-down viewport, with buttons that fire its board-cleared / new-ball
## reactions. Rebuilds the background when the skin changes.

## The background renders at full screen size and is shown scaled.
const BG_SCALE := 0.42
const STRIP_HEIGHT := 150.0
const BALL_RADIUS := 44.0

var _strip: Control
var _t: float = 0.0
var _bg_holder: Control
var _viewport: SubViewport
var _bg: AnimatedBackground
var _flat: ColorRect
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
	_bg_holder = Control.new()
	_bg_holder.custom_minimum_size = view * BG_SCALE
	_bg_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bg_holder.clip_contents = true
	add_child(_bg_holder)

	var container := SubViewportContainer.new()
	container.size = view
	container.scale = Vector2.ONE * BG_SCALE
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_holder.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(view)
	container.add_child(_viewport)
	_flat = ColorRect.new()
	_flat.size = view
	_viewport.add_child(_flat)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_clear_btn = NeonUI.button("BOARD CLEARED")
	_clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clear_btn.pressed.connect(func() -> void:
		if is_instance_valid(_bg):
			_bg.on_board_cleared(view * 0.5))
	row.add_child(_clear_btn)
	_new_btn = NeonUI.button("NEW BALL")
	_new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_btn.pressed.connect(func() -> void:
		if is_instance_valid(_bg):
			_bg.on_new_ball(Vector2(randf_range(0.15, 0.85) * view.x, randf_range(0.3, 0.9) * view.y)))
	row.add_child(_new_btn)
	add_child(row)

	# A method connection disconnects itself when this node is freed.
	Skins.changed.connect(_sync)

func _ready() -> void:
	_sync()

func _process(delta: float) -> void:
	_t += delta
	_strip.queue_redraw()

func _sync() -> void:
	var skin := Skins.background()
	_flat.color = skin.color
	if is_instance_valid(_bg) and _bg.get_script() == skin.scene:
		return
	if is_instance_valid(_bg):
		_bg.queue_free()
		_bg = null
	if skin.scene != null:
		_bg = skin.scene.new() as AnimatedBackground
		_viewport.add_child(_bg)
		_bg.show_behind_parent = false
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
