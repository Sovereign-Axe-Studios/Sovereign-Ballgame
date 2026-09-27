class_name SkinsPanel
extends VBoxContainer
## The Skins pickers -- ball, background, block, launcher -- shared by the
## pause menu, the title screen and the Asset Viewer (three copies before).
## Each category is a preview swatch, a title, and a row of NeonUI chips;
## locked skins are disabled "???" chips. Selection goes through `Skins`.
##
## Backgrounds also get a live BackgroundPreview beside their chips, and
## blocks a BlockRampPreview (a wall of bricks across the colour ramp); both
## show the chip under the mouse and fall back to the selected one. A host with
## its own bigger preview (the Asset Viewer) turns that off and listens to
## `background_hovered` instead.

## The background chip under the mouse, or the selected one when it leaves.
signal background_hovered(skin: Skins.BackgroundSkin)

const SWATCH := Vector2(72.0, 72.0)
## The inline background preview, as a fraction of the screen.
const BG_PREVIEW_SCALE := 0.2

var _bg_preview: BackgroundPreview
var _block_preview := BlockRampPreview.new()

func _init(inline_background_preview: bool = true) -> void:
	if inline_background_preview:
		_bg_preview = BackgroundPreview.new(BG_PREVIEW_SCALE)
		background_hovered.connect(_bg_preview.show_skin)

	add_theme_constant_override("separation", 26)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	add_child(_category(_ball_swatch(), "Ball", Skins.picker_names(Skins.ball_skins),
		func() -> int: return Skins.ball_index,
		func(i: int) -> void: Skins.set_ball(i)))
	add_child(_category(_background_swatch(), "Background", Skins.picker_names(Skins.background_skins),
		func() -> int: return Skins.background_index,
		func(i: int) -> void: Skins.set_background(i),
		_on_background_hover, _bg_preview))
	add_child(_category(_block_swatch(), "Block", Skins.picker_names(Skins.block_skins),
		func() -> int: return Skins.block_index,
		func(i: int) -> void: Skins.set_block(i),
		_on_block_hover, _block_preview))
	add_child(_category(_launcher_swatch(), "Launcher", Skins.picker_names(Skins.launcher_skins),
		func() -> int: return Skins.launcher_index,
		func(i: int) -> void: Skins.set_launcher(i)))
	# Method connections: they disconnect themselves when this panel is freed.
	Skins.changed.connect(_show_selected_background)
	Skins.changed.connect(_show_selected_block)

func _ready() -> void:
	_show_selected_background()
	_show_selected_block()

## `i` = hovered block chip, -1 = the mouse left it.
func _on_block_hover(i: int) -> void:
	if i < 0 or Skins.block_skins[i].is_locked():
		_show_selected_block()
	else:
		_block_preview.show_skin(Skins.block_skins[i])

func _show_selected_block() -> void:
	_block_preview.show_skin(Skins.block())

## `i` = hovered chip, -1 = the mouse left it (show the selection again).
## Locked backgrounds stay hidden, like their ??? chips.
func _on_background_hover(i: int) -> void:
	if i < 0 or Skins.background_skins[i].is_locked():
		_show_selected_background()
	else:
		background_hovered.emit(Skins.background_skins[i])

func _show_selected_background() -> void:
	background_hovered.emit(Skins.background())

## Swatch + title, then a chip per option (radio-style via ButtonGroup).
## `on_hover(i)` (optional) hears chip i entered, -1 when the mouse leaves one.
## `side` (optional) sits to the right of the chips (the background preview).
func _category(swatch: Control, title: String, names: Array, get_index: Callable,
		on_select: Callable, on_hover: Callable = Callable(), side: Control = null) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 12)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 18)
	header_row.add_child(swatch)
	var title_label := NeonUI.subheader(title)
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(title_label)
	wrap.add_child(header_row)

	var group := ButtonGroup.new()
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 14)
	chips.add_theme_constant_override("v_separation", 14)
	var buttons: Array[Button] = []
	for i in range(names.size()):
		var btn := NeonUI.chip(str(names[i]))
		btn.button_group = group
		btn.button_pressed = i == get_index.call()
		if str(names[i]) == Skins.LOCKED_NAME:
			btn.disabled = true
			btn.tooltip_text = Skins.LOCKED_HINT
		btn.pressed.connect(func() -> void: on_select.call(i))
		if on_hover.is_valid():
			btn.mouse_entered.connect(func() -> void: on_hover.call(i))
			btn.mouse_exited.connect(func() -> void: on_hover.call(-1))
		chips.add_child(btn)
		buttons.append(btn)
	# A lambda on an autoload signal is NOT auto-disconnected when the buttons
	# it captured are freed (a method connection would be); disconnect it when
	# this row leaves the tree.
	var sync := func() -> void:
		var idx: int = get_index.call()
		for i in range(buttons.size()):
			buttons[i].set_pressed_no_signal(i == idx)
	Skins.changed.connect(sync)
	wrap.tree_exiting.connect(func() -> void: Skins.changed.disconnect(sync))
	if side == null:
		wrap.add_child(chips)
		return wrap
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(chips)
	row.add_child(side)
	wrap.add_child(row)
	return wrap


# ---------------------------------------------------------------- swatches
# Plain Controls drawn via their own `draw` signal; `Skins.changed` is a
# method connection (queue_redraw), so it disconnects itself on free.

func _swatch(draw_fn: Callable) -> Control:
	var c := Control.new()
	c.custom_minimum_size = SWATCH
	c.draw.connect(func() -> void: draw_fn.call(c))
	Skins.changed.connect(c.queue_redraw)
	return c

func _ball_swatch() -> Control:
	return _swatch(func(c: Control) -> void:
		PreviewDraw.ball(c, SWATCH * 0.5, SWATCH.x * 0.4))

func _background_swatch() -> Control:
	return _swatch(func(c: Control) -> void:
		c.draw_rect(Rect2(Vector2.ZERO, SWATCH), Skins.background().color, true)
		c.draw_rect(Rect2(Vector2.ZERO, SWATCH), Color(NeonUI.CYAN, 0.5), false, 2.0))

func _block_swatch() -> Control:
	return _swatch(func(c: Control) -> void:
		var ramp: Array[Color] = Skins.block().ramp
		var w := SWATCH.x / float(ramp.size())
		for i in range(ramp.size()):
			c.draw_rect(Rect2(Vector2(float(i) * w, 0.0), Vector2(w + 1.0, SWATCH.y)), ramp[i], true))

func _launcher_swatch() -> Control:
	return _swatch(func(c: Control) -> void:
		var accent := Skins.ball().color
		var center := SWATCH * 0.5
		# if/elif, not match: an autoload's enum isn't a valid match pattern.
		var shape := Skins.launcher().shape
		if shape == Skins.LauncherShape.PROBE_CANNON:
			Shooter.draw_probe_cannon(c, Vector2(center.x, SWATCH.y - 14.0), Vector2.UP, 0.6)
		elif shape == Skins.LauncherShape.CANNON:
			c.draw_rect(Rect2(Vector2(center.x - 9.0, 6.0), Vector2(18.0, SWATCH.y - 26.0)), Color("#4b5563"), true)
			c.draw_circle(Vector2(center.x, SWATCH.y - 16.0), 18.0, Color("#242830"))
			c.draw_circle(Vector2(center.x, 10.0), 8.0, accent)
		else:
			c.draw_circle(center, SWATCH.x * 0.35, accent))
