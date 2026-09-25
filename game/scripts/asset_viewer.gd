class_name AssetViewer
extends Node2D
## Browses what the project actually has right now, in tabs: Skins (ball /
## background / block / launcher, same chip-picker as the pause menu's Skins
## page), Modes (ball-return behaviour + a Game Mods stub -- there are no
## mods yet), Audio (SFX/Music bus volume -- no sound assets exist yet
## either, so this is buses and sliders, not a sound library).
##
## Deliberately NOT padded out to match a richer reference screen from
## another Sovereign Axe title -- every tab here reflects what this project
## actually contains today rather than placeholder rows for content that
## doesn't exist.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

var _return_mode_option: OptionButton

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var vp := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	var layer := CanvasLayer.new()
	add_child(layer)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Skins.background().color.darkened(0.1)
	layer.add_child(bg)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var header := Label.new()
	header.text = "ASSET VIEWER"
	header.position = Vector2(40.0, 30.0)
	header.size = Vector2(vp.x - 80.0, 70.0)
	header.add_theme_font_size_override("font_size", 44)
	header.add_theme_color_override("font_color", Skins.ball().color)
	root.add_child(header)

	var back_btn := Button.new()
	back_btn.text = "← BACK"
	back_btn.position = Vector2(40.0, 110.0)
	back_btn.custom_minimum_size = Vector2(160.0, 60.0)
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU_SCENE))
	root.add_child(back_btn)

	var tabs := TabContainer.new()
	tabs.position = Vector2(40.0, 190.0)
	tabs.size = Vector2(vp.x - 80.0, vp.y - 240.0)
	tabs.add_theme_font_size_override("font_size", 26)
	root.add_child(tabs)

	tabs.add_child(_build_skins_tab())
	tabs.add_child(_build_modes_tab())
	tabs.add_child(_build_audio_tab())


# --------------------------------------------------------------- skins tab

func _build_skins_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Skins"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 30)
	scroll.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	margin.add_child(col)

	var ball_names: Array = Skins.picker_names(Skins.ball_skins)
	col.add_child(_skin_category(_ball_preview(), "Ball", ball_names,
		func() -> int: return Skins.ball_index,
		func(i: int) -> void: Skins.set_ball(i)))

	var bg_names: Array = Skins.picker_names(Skins.background_skins)
	col.add_child(_skin_category(_background_preview(), "Background", bg_names,
		func() -> int: return Skins.background_index,
		func(i: int) -> void: Skins.set_background(i)))

	var block_names: Array = Skins.picker_names(Skins.block_skins)
	col.add_child(_skin_category(_block_preview(), "Block", block_names,
		func() -> int: return Skins.block_index,
		func(i: int) -> void: Skins.set_block(i)))

	var launcher_names: Array = Skins.picker_names(Skins.launcher_skins)
	col.add_child(_skin_category(_launcher_preview(), "Launcher", launcher_names,
		func() -> int: return Skins.launcher_index,
		func(i: int) -> void: Skins.set_launcher(i)))

	return scroll

func _skin_category(preview: Control, title: String, names: Array, get_index: Callable, on_select: Callable) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 10)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	header_row.add_child(preview)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Palette.TEXT)
	header_row.add_child(title_label)
	wrap.add_child(header_row)

	var group := ButtonGroup.new()
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 10)
	chips.add_theme_constant_override("v_separation", 10)
	var buttons: Array[Button] = []
	for i in range(names.size()):
		var btn := _chip_button(str(names[i]))
		btn.button_group = group
		btn.button_pressed = i == get_index.call()
		if str(names[i]) == Skins.LOCKED_NAME:
			btn.disabled = true
			btn.tooltip_text = Skins.LOCKED_HINT
		btn.pressed.connect(func() -> void: on_select.call(i))
		chips.add_child(btn)
		buttons.append(btn)
	# A lambda on an autoload signal is NOT auto-disconnected when the
	# buttons it captured are freed (a method connection would be), so it
	# would fire into freed buttons after the next scene change. Disconnect
	# it when this row leaves the tree.
	var sync := func() -> void:
		var idx: int = get_index.call()
		for i in range(buttons.size()):
			buttons[i].button_pressed = i == idx
	Skins.changed.connect(sync)
	wrap.tree_exiting.connect(func() -> void: Skins.changed.disconnect(sync))
	wrap.add_child(chips)
	return wrap

func _chip_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0.0, 56.0)
	b.add_theme_font_size_override("font_size", 22)
	return b


# --------------------------------------------------------------- modes tab

func _build_modes_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Modes"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 30)
	scroll.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	margin.add_child(col)

	col.add_child(_section_label("Ball return behaviour"))
	_return_mode_option = OptionButton.new()
	_return_mode_option.custom_minimum_size = Vector2(0.0, 64.0)
	_return_mode_option.add_theme_font_size_override("font_size", 24)
	for mode in range(Skins.ReturnMode.size()):
		_return_mode_option.add_item(Skins.RETURN_MODE_NAMES[mode], mode)
	_return_mode_option.select(Skins.return_mode)
	_return_mode_option.item_selected.connect(func(index: int) -> void:
		Skins.set_return_mode(_return_mode_option.get_item_id(index) as Skins.ReturnMode))
	col.add_child(_return_mode_option)

	col.add_child(_section_label("Game mods"))
	var mods_note := Label.new()
	mods_note.text = "None built yet -- this is a stub. See docs/HANDOFF.md §5, the mod layer's design section."
	mods_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mods_note.add_theme_font_size_override("font_size", 22)
	mods_note.add_theme_color_override("font_color", Palette.TEXT_DIM)
	col.add_child(mods_note)

	return scroll

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Palette.TEXT)
	return l


# --------------------------------------------------------------- audio tab

func _build_audio_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Audio"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 30)
	scroll.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	margin.add_child(col)

	var note := Label.new()
	note.text = "No sound assets exist yet -- these are real audio buses (audio/bus_layout.tres) and their volume sliders, with nothing routed through them to hear yet."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 22)
	note.add_theme_color_override("font_color", Palette.TEXT_DIM)
	col.add_child(note)

	var sfx := _slider_row(col, "SFX volume", 0.0, 100.0)
	sfx.value = Settings.sfx_volume * 100.0
	sfx.value_changed.connect(func(v: float) -> void: Settings.set_sfx_volume(v / 100.0))

	var music := _slider_row(col, "Music volume", 0.0, 100.0)
	music.value = Settings.music_volume * 100.0
	music.value_changed.connect(func(v: float) -> void: Settings.set_music_volume(v / 100.0))

	return scroll

func _slider_row(col: VBoxContainer, caption: String, lo: float, hi: float) -> HSlider:
	col.add_child(_section_label(caption))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1.0
	s.custom_minimum_size = Vector2(0.0, 40.0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(s)
	return s


# ------------------------------------------------------------- skin previews

func _ball_preview() -> Control:
	var size := Vector2(64.0, 64.0)
	var c := Control.new()
	c.custom_minimum_size = size
	c.draw.connect(func() -> void:
		var skin := Skins.ball()
		var center := size * 0.5
		c.draw_circle(center, size.x * 0.42, skin.color)
		c.draw_circle(center + Vector2(-size.x * 0.14, -size.x * 0.14), size.x * 0.13, skin.highlight))
	Skins.changed.connect(c.queue_redraw)
	return c

func _background_preview() -> Control:
	var size := Vector2(64.0, 64.0)
	var c := Control.new()
	c.custom_minimum_size = size
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(Vector2.ZERO, size), Skins.background().color, true)
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.2), false, 2.0))
	Skins.changed.connect(c.queue_redraw)
	return c

func _block_preview() -> Control:
	var size := Vector2(64.0, 64.0)
	var c := Control.new()
	c.custom_minimum_size = size
	c.draw.connect(func() -> void:
		var ramp: Array[Color] = Skins.block().ramp
		var w := size.x / float(ramp.size())
		for i in range(ramp.size()):
			c.draw_rect(Rect2(Vector2(float(i) * w, 0.0), Vector2(w + 1.0, size.y)), ramp[i], true))
	Skins.changed.connect(c.queue_redraw)
	return c

func _launcher_preview() -> Control:
	var size := Vector2(64.0, 64.0)
	var c := Control.new()
	c.custom_minimum_size = size
	c.draw.connect(func() -> void:
		var accent := Skins.ball().color
		var center := size * 0.5
		if Skins.launcher().shape == Skins.LauncherShape.PROBE_CANNON:
			Shooter.draw_probe_cannon(c, Vector2(center.x, size.y - 14.0), Vector2.UP, 0.55)
		elif Skins.launcher().shape == Skins.LauncherShape.CANNON:
			c.draw_rect(Rect2(Vector2(center.x - 9.0, 6.0), Vector2(18.0, size.y - 26.0)), Color("#4b5563"), true)
			c.draw_circle(Vector2(center.x, size.y - 16.0), 18.0, Color("#242830"))
			c.draw_circle(Vector2(center.x, 10.0), 8.0, accent)
		else:
			c.draw_circle(center, size.x * 0.35, accent))
	Skins.changed.connect(c.queue_redraw)
	return c
