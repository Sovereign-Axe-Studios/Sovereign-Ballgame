class_name BackgroundPreview
extends Control
## A live, scaled-down view of a background skin: the real AnimatedBackground
## node (or the flat colour) running full-size in a SubViewport and shown at
## `view_scale`. Used by SkinsPanel (hover / selected) and SkinPreview (the
## Asset Viewer's big preview with reaction buttons).

var _viewport: SubViewport
var _flat: ColorRect
var _bg: AnimatedBackground
var _skin: Skins.BackgroundSkin

func _init(view_scale: float) -> void:
	var view := NeonUI.view_size()
	custom_minimum_size = view * view_scale
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var container := SubViewportContainer.new()
	container.size = view
	container.scale = Vector2.ONE * view_scale
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(view)
	# Its own World2D: by default a SubViewport shares its parent's, and the
	# 2D canvas lives in the World2D -- so it drew the game's blocks and balls,
	# and the background node added here leaked into the game's canvas too.
	_viewport.world_2d = World2D.new()
	container.add_child(_viewport)
	_flat = ColorRect.new()
	_flat.size = view
	_viewport.add_child(_flat)

	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color(NeonUI.CYAN, 0.6)
	sb.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", sb)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

## Show `skin`. A no-op if it's already showing, so hovering back and forth
## over the same chip doesn't restart its animation.
func show_skin(skin: Skins.BackgroundSkin) -> void:
	if skin == _skin:
		return
	_skin = skin
	_flat.color = skin.color
	if is_instance_valid(_bg):
		_bg.queue_free()
		_bg = null
	if skin.scene != null:
		_bg = skin.scene.new() as AnimatedBackground
		_viewport.add_child(_bg)
		_bg.show_behind_parent = false

## The running animated background, or null for a flat one.
func current() -> AnimatedBackground:
	return _bg if is_instance_valid(_bg) else null
