class_name ModeSelect
extends Node2D
## Play -> pick a mode. Two pages:
##   List:   the curated modes (CuratedModes.all()), then CUSTOM, then BACK.
##           A curated mode starts the run immediately.
##   Custom: one row per GameMod.Category -- a chip for None plus each of that
##           category's mods from Cfg.MODS. NEXT starts the run.
## Built in code in the title screen's arcade style (ArcadeUI), like every
## other screen here. Esc steps back a page, then to the title screen.

const TITLE_SCENE := "res://scenes/main_menu.tscn"
const PAGE_WIDTH := 880.0

var _list_page: Control
var _custom_page: Control
## Category -> the GDScript picked on the Custom page (absent = None).
var _picks: Dictionary = {}

func _ready() -> void:
	_build_ui()
	_show(_list_page)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _custom_page.visible:
		_show(_list_page)
	else:
		get_tree().change_scene_to_file(TITLE_SCENE)
	get_viewport().set_input_as_handled()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _viewport_size()), Skins.background().color.darkened(0.2), true)

func _viewport_size() -> Vector2:
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)

func _show(page: Control) -> void:
	_list_page.visible = page == _list_page
	_custom_page.visible = page == _custom_page

func _start_custom() -> void:
	var mods: Array[GDScript] = []
	for c in GameMod.Category.values():
		if _picks.has(c):
			mods.append(_picks[c])
	Run.start("Custom", mods)


# ------------------------------------------------------------------- layout

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_list_page = _build_list_page()
	root.add_child(_list_page)
	_custom_page = _build_custom_page()
	root.add_child(_custom_page)

## A full-screen scroll page with a centred column of PAGE_WIDTH.
func _page(title: String) -> Array:
	var vp := _viewport_size()
	var scroll := ScrollContainer.new()
	scroll.position = Vector2.ZERO
	scroll.size = vp
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var margin := MarginContainer.new()
	margin.custom_minimum_size = Vector2(vp.x, 0.0)
	var side := int((vp.x - PAGE_WIDTH) * 0.5)
	margin.add_theme_constant_override("margin_left", side)
	margin.add_theme_constant_override("margin_right", side)
	margin.add_theme_constant_override("margin_top", 120)
	margin.add_theme_constant_override("margin_bottom", 80)
	scroll.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	margin.add_child(col)

	var header := ArcadeUI.label(title, 64, Skins.ball().color)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(header)
	col.add_child(_spacer(20.0))
	return [scroll, col]

func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, height)
	return c

func _build_list_page() -> Control:
	var parts := _page("SELECT MODE")
	var col: VBoxContainer = parts[1]

	for mode: Dictionary in CuratedModes.all():
		var btn := ArcadeUI.button("▶ " + str(mode.name).to_upper())
		var mode_name: String = mode.name
		var mode_mods: Array[GDScript] = mode.mods
		btn.pressed.connect(func() -> void: Run.start(mode_name, mode_mods))
		col.add_child(btn)
		col.add_child(ArcadeUI.label("%s\n%s" % [mode.description, _mod_names(mode_mods)], 24, Palette.TEXT_DIM))
		col.add_child(_spacer(12.0))

	var custom_btn := ArcadeUI.button("✎ CUSTOM")
	custom_btn.pressed.connect(func() -> void: _show(_custom_page))
	col.add_child(custom_btn)
	col.add_child(ArcadeUI.label("Pick one mod per category.", 24, Palette.TEXT_DIM))
	col.add_child(_spacer(40.0))

	var back_btn := ArcadeUI.button("BACK")
	back_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))
	col.add_child(back_btn)
	return parts[0]

func _mod_names(scripts: Array[GDScript]) -> String:
	var names: Array[String] = []
	for script in scripts:
		names.append((script.new() as GameMod).display_name)
	return "Mods: " + ", ".join(names)

func _build_custom_page() -> Control:
	var parts := _page("CUSTOM MODE")
	var col: VBoxContainer = parts[1]

	# One instance per registered mod, just to read its category and text.
	var by_category: Dictionary = {}
	for script in Cfg.MODS:
		var mod := script.new() as GameMod
		if not by_category.has(mod.category):
			by_category[mod.category] = []
		(by_category[mod.category] as Array).append([script, mod])

	for c in GameMod.Category.values():
		col.add_child(_category_row(c, by_category.get(c, [])))

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 24)
	var back_btn := ArcadeUI.button("BACK")
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void: _show(_list_page))
	nav.add_child(back_btn)
	var next_btn := ArcadeUI.button("NEXT ▶")
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_btn.pressed.connect(_start_custom)
	nav.add_child(next_btn)
	col.add_child(_spacer(20.0))
	col.add_child(nav)
	return parts[0]

## Category title, a chip per option (None first), and the selected option's
## description underneath. `entries` is [[script, instance], ...].
func _category_row(c: GameMod.Category, entries: Array) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(ArcadeUI.label(GameMod.category_name(c).to_upper(), 30))

	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 12)
	chips.add_theme_constant_override("v_separation", 12)
	row.add_child(chips)

	var desc := ArcadeUI.label("Stock rules.", 22, Palette.TEXT_DIM)
	var group := ButtonGroup.new()

	var none := ArcadeUI.chip("None")
	none.button_group = group
	none.button_pressed = true
	none.pressed.connect(func() -> void:
		_picks.erase(c)
		desc.text = "Stock rules.")
	chips.add_child(none)

	for entry: Array in entries:
		var script: GDScript = entry[0]
		var mod: GameMod = entry[1]
		var chip := ArcadeUI.chip(mod.display_name)
		chip.button_group = group
		chip.tooltip_text = mod.description
		chip.disabled = not mod.available
		chip.pressed.connect(func() -> void:
			_picks[c] = script
			desc.text = mod.description)
		chips.add_child(chip)

	row.add_child(desc)
	row.add_child(_spacer(8.0))
	return row
