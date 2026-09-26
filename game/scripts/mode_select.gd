class_name ModeSelect
extends Node2D
## Play -> pick a mode. Two pages:
##   List:   the curated modes (CuratedModes.all()), then CUSTOM, then BACK.
##           A curated mode starts the run immediately.
##   Custom: a character-select grid -- one neon row per GameMod.Category,
##           a tile for None plus each of that category's mods from Cfg.MODS.
##           Tiles animate their draw_preview on hover; the ? corner opens a
##           detail panel with a live mini-board (ModLivePreview). Locked mods
##           show as ??? silhouettes. NEXT starts the run.
## Built in code in the neon style (NeonUI) over a GeometricBackdrop, like every
## other screen here. Esc steps back a page, then to the title screen.

const TITLE_SCENE := "res://scenes/main_menu.tscn"
const PAGE_WIDTH := 880.0
const TILE_SIZE := Vector2(156.0, 172.0)
const ICON_SIZE := 112.0
const DETAIL_PREVIEW_SIZE := Vector2(420.0, 560.0)
const LOCKED_HINT := "Look to the stars."

var _root: Control
var _detail: Control
var _list_page: Control
var _custom_page: Control
## Category -> the GDScript picked on the Custom page (absent = None).
var _picks: Dictionary = {}

func _ready() -> void:
	add_child(GeometricBackdrop.new())
	_build_ui()
	_show(_list_page)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _detail != null:
		_close_detail()
	elif _custom_page.visible:
		_show(_list_page)
	else:
		get_tree().change_scene_to_file(TITLE_SCENE)
	get_viewport().set_input_as_handled()


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
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_root)

	_list_page = _build_list_page()
	_root.add_child(_list_page)
	_custom_page = _build_custom_page()
	_root.add_child(_custom_page)

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

	col.add_child(NeonUI.header(title))
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
		var btn := NeonUI.button(str(mode.name).to_upper(), true)
		var mode_name: String = mode.name
		var mode_mods: Array[GDScript] = mode.mods
		btn.pressed.connect(func() -> void: Run.start(mode_name, mode_mods))
		col.add_child(btn)
		col.add_child(NeonUI.label("%s\n%s" % [mode.description, _mod_names(mode_mods)], 24, NeonUI.TEXT_DIM))
		col.add_child(_spacer(12.0))

	var custom_btn := NeonUI.button("CUSTOM")
	custom_btn.pressed.connect(func() -> void: _show(_custom_page))
	col.add_child(custom_btn)
	col.add_child(NeonUI.label("Pick one mod per category.", 24, NeonUI.TEXT_DIM))
	col.add_child(_spacer(40.0))

	var back_btn := NeonUI.button("BACK")
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
	var back_btn := NeonUI.button("BACK")
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void: _show(_list_page))
	nav.add_child(back_btn)
	var next_btn := NeonUI.button("NEXT", true)
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_btn.pressed.connect(_start_custom)
	nav.add_child(next_btn)
	col.add_child(_spacer(20.0))
	col.add_child(nav)
	return parts[0]

## Character-select row: a neon category header, then a tile per option
## (None first). `entries` is [[script, instance], ...].
func _category_row(c: GameMod.Category, entries: Array) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(NeonUI.subheader(GameMod.category_name(c)))

	var tiles := HFlowContainer.new()
	tiles.add_theme_constant_override("h_separation", 14)
	tiles.add_theme_constant_override("v_separation", 14)
	row.add_child(tiles)

	var group := ButtonGroup.new()
	var none := _tile(null, false)
	none.button_group = group
	none.button_pressed = true
	none.pressed.connect(func() -> void: _picks.erase(c))
	tiles.add_child(none)

	for entry: Array in entries:
		var script: GDScript = entry[0]
		var mod: GameMod = entry[1]
		var locked := not Unlocks.is_unlocked(mod.locked_by)
		var tile := _tile(mod, locked)
		tile.button_group = group
		tile.pressed.connect(func() -> void: _picks[c] = script)
		tiles.add_child(tile)

	row.add_child(_spacer(6.0))
	return row

## One mod tile: animated icon + name, and a ? corner button that opens the
## detail panel. `mod == null` is the None tile.
func _tile(mod: GameMod, locked: bool) -> Button:
	var tile := NeonUI.chip("", 0.0)
	tile.custom_minimum_size = TILE_SIZE
	tile.clip_contents = true

	var icon := ModPreviewIcon.new(mod, locked)
	icon.position = Vector2((TILE_SIZE.x - ICON_SIZE) * 0.5, 14.0)
	icon.size = Vector2.ONE * ICON_SIZE
	tile.add_child(icon)

	var label_text := "None"
	if mod != null:
		label_text = "???" if locked else mod.display_name
	var name_label := NeonUI.label(label_text, 20, NeonUI.TEXT)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(6.0, 14.0 + ICON_SIZE + 6.0)
	name_label.size = Vector2(TILE_SIZE.x - 12.0, 30.0)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(name_label)

	if mod == null:
		tile.tooltip_text = "Stock rules for this category."
		return tile
	if locked:
		tile.disabled = true
		tile.tooltip_text = LOCKED_HINT
		return tile
	tile.tooltip_text = mod.description
	tile.disabled = not mod.available
	tile.mouse_entered.connect(func() -> void: icon.playing = true)
	tile.mouse_exited.connect(func() -> void: icon.playing = false)

	var help := Button.new()
	help.text = "?"
	help.focus_mode = Control.FOCUS_NONE
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", PreviewDraw.GLOW)
	for state in ["normal", "hover", "pressed"]:
		var sb := NeonUI.box(state != "normal", NeonUI.MAGENTA, 0.0)
		sb.set_content_margin_all(2.0)
		sb.set_border_width_all(2)
		help.add_theme_stylebox_override(state, sb)
	help.size = Vector2(34.0, 34.0)
	help.position = Vector2(TILE_SIZE.x - 38.0, 4.0)
	help.tooltip_text = "What does this do?"
	help.pressed.connect(func() -> void: _open_detail(mod))
	tile.add_child(help)
	return tile


# ------------------------------------------------------------- detail panel

func _open_detail(mod: GameMod) -> void:
	_close_detail()
	_detail = Control.new()
	_detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_detail)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.75)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_close_detail())
	_detail.add_child(dim)

	var vp := _viewport_size()
	var panel := PanelContainer.new()
	var panel_style := NeonUI.panel_style()
	panel_style.set_content_margin_all(32.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.custom_minimum_size = Vector2(PAGE_WIDTH, 0.0)
	panel.position = Vector2((vp.x - PAGE_WIDTH) * 0.5, 160.0)
	_detail.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	panel.add_child(col)
	col.add_child(NeonUI.label(GameMod.category_name(mod.category).to_upper(), 24, NeonUI.TEXT_DIM))
	col.add_child(NeonUI.label(mod.display_name, 52, NeonUI.CYAN))
	col.add_child(NeonUI.label(mod.description, 28))

	var preview_box := CenterContainer.new()
	col.add_child(preview_box)
	# A fresh instance: the live board installs it into its own GameRules, and
	# stateful mods (Lives) mustn't share state with the tile's copy.
	var fresh := (mod.get_script() as GDScript).new() as GameMod
	if fresh.live_preview:
		preview_box.add_child(ModLivePreview.new(fresh, DETAIL_PREVIEW_SIZE))
	else:
		var big := ModPreviewIcon.new(fresh)
		big.custom_minimum_size = Vector2.ONE * DETAIL_PREVIEW_SIZE.x
		big.playing = true
		preview_box.add_child(big)

	var close_btn := NeonUI.button("CLOSE")
	close_btn.pressed.connect(_close_detail)
	col.add_child(close_btn)

func _close_detail() -> void:
	if _detail != null:
		_detail.queue_free()
		_detail = null
