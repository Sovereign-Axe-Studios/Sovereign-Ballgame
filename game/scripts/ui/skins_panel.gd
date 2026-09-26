class_name SkinsPanel
extends VBoxContainer
## The Skins pickers -- ball, background, block, launcher -- shared by the
## pause menu, the title screen and the Asset Viewer (three copies before).
## Each category is a preview swatch, a title, and a row of NeonUI chips;
## locked skins are disabled "???" chips. Selection goes through `Skins`.

const SWATCH := Vector2(72.0, 72.0)

func _init() -> void:
	add_theme_constant_override("separation", 26)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	add_child(_category(_ball_swatch(), "Ball", Skins.picker_names(Skins.ball_skins),
		func() -> int: return Skins.ball_index,
		func(i: int) -> void: Skins.set_ball(i)))
	add_child(_category(_background_swatch(), "Background", Skins.picker_names(Skins.background_skins),
		func() -> int: return Skins.background_index,
		func(i: int) -> void: Skins.set_background(i)))
	add_child(_category(_block_swatch(), "Block", Skins.picker_names(Skins.block_skins),
		func() -> int: return Skins.block_index,
		func(i: int) -> void: Skins.set_block(i)))
	add_child(_category(_launcher_swatch(), "Launcher", Skins.picker_names(Skins.launcher_skins),
		func() -> int: return Skins.launcher_index,
		func(i: int) -> void: Skins.set_launcher(i)))

## Swatch + title, then a chip per option (radio-style via ButtonGroup).
func _category(swatch: Control, title: String, names: Array, get_index: Callable,
		on_select: Callable) -> VBoxContainer:
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
	wrap.add_child(chips)
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
