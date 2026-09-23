extends CanvasLayer
class_name PauseMenu
## The pause menu: Resume / Settings / Debug Menu / Main Menu on the root
## page, with Settings and Debug Menu each opening their own page. Built in
## code rather than laid out in a .tscn -- see docs/HANDOFF.md §7 on why
## hand-written scene UI is the riskiest part of this project, and
## Game._build_walls for the existing precedent.
##
## `process_mode = ALWAYS` (set in _ready) so this keeps taking input while
## `get_tree().paused` is true -- that IS the pause menu's job.

signal grid_apply_requested(width: int, height: int, kill_row: int, spawn_row: int)

var _game: Game
var _ui_root: Control
var _root_page: Control
var _settings_page: Control
var _debug_page: Control

var _debug_check: CheckBox
var _width_box: SpinBox
var _height_box: SpinBox
var _kill_box: SpinBox
var _spawn_box: SpinBox

var _ui_scale_slider: HSlider
var _shake_slider: HSlider
var _sfx_slider: HSlider
var _music_slider: HSlider

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_game = get_parent() as Game
	_build_ui()
	Settings.changed.connect(_apply_ui_scale)
	_apply_ui_scale()
	visible = false
	_show_page(_root_page)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()

func open() -> void:
	_sync_fields()
	_show_page(_root_page)
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func _apply_ui_scale() -> void:
	_ui_root.scale = Vector2.ONE * Settings.ui_scale

func _show_page(page: Control) -> void:
	_root_page.visible = page == _root_page
	_settings_page.visible = page == _settings_page
	_debug_page.visible = page == _debug_page

func _sync_fields() -> void:
	_debug_check.button_pressed = Debug.enabled
	_width_box.value = _game.rules.grid_width
	_height_box.value = _game.rules.grid_height
	_kill_box.value = _game.rules.death_row()
	_spawn_box.value = _game.rules.spawn_row_index
	_ui_scale_slider.value = Settings.ui_scale * 100.0
	_shake_slider.value = Settings.screen_shake_strength * 100.0
	_sfx_slider.value = Settings.sfx_volume * 100.0
	_music_slider.value = Settings.music_volume * 100.0

func _on_apply_grid() -> void:
	grid_apply_requested.emit(int(_width_box.value), int(_height_box.value), int(_kill_box.value), int(_spawn_box.value))
	_sync_fields()


# ------------------------------------------------------------------- layout

func _build_ui() -> void:
	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_root.pivot_offset = Vector2.ZERO
	add_child(_ui_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	_ui_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.position = Vector2(140.0, 220.0)
	panel.custom_minimum_size = Vector2(800.0, 1480.0)
	_ui_root.add_child(panel)

	# All three pages share one container so only one is ever visible; each
	# page owns its own scroll/back button rather than the panel owning tabs,
	# since the root page has none.
	var stack := Control.new()
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(stack)

	_root_page = _build_root_page()
	_settings_page = _build_settings_page()
	_debug_page = _build_debug_page()
	stack.add_child(_root_page)
	stack.add_child(_settings_page)
	stack.add_child(_debug_page)

func _page_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 22)
	return col

func _build_root_page() -> Control:
	var col := _page_column()
	col.add_child(_label("PAUSED", 52))

	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.pressed.connect(close)
	col.add_child(resume_btn)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.pressed.connect(func() -> void: _show_page(_settings_page))
	col.add_child(settings_btn)

	var debug_btn := Button.new()
	debug_btn.text = "Debug Menu"
	debug_btn.pressed.connect(func() -> void:
		_sync_fields()
		_show_page(_debug_page))
	col.add_child(debug_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Main menu"
	menu_btn.disabled = true
	menu_btn.tooltip_text = "Stub -- there is no main menu scene yet."
	col.add_child(menu_btn)

	return col

func _build_settings_page() -> Control:
	var col := _page_column()
	col.add_child(_label("SETTINGS", 44))

	_ui_scale_slider = _labeled_slider(col, "UI scale", 50.0, 200.0)
	_ui_scale_slider.value_changed.connect(func(v: float) -> void: Settings.set_ui_scale(v / 100.0))

	_shake_slider = _labeled_slider(col, "Screen shake strength", 0.0, 100.0)
	_shake_slider.value_changed.connect(func(v: float) -> void: Settings.set_screen_shake_strength(v / 100.0))

	_sfx_slider = _labeled_slider(col, "SFX volume", 0.0, 100.0)
	_sfx_slider.value_changed.connect(func(v: float) -> void: Settings.set_sfx_volume(v / 100.0))

	_music_slider = _labeled_slider(col, "Music volume", 0.0, 100.0)
	_music_slider.value_changed.connect(func(v: float) -> void: Settings.set_music_volume(v / 100.0))

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(func() -> void: _show_page(_root_page))
	col.add_child(back_btn)

	return col

func _build_debug_page() -> Control:
	var col := _page_column()
	col.add_child(_label("DEBUG MENU", 44))

	_debug_check = CheckBox.new()
	_debug_check.text = "Enable debug mode"
	_debug_check.toggled.connect(func(pressed: bool) -> void: Debug.enabled = pressed)
	col.add_child(_debug_check)

	col.add_child(_label("Change game mods", 26))
	var mods_btn := Button.new()
	mods_btn.text = "Mods..."
	mods_btn.disabled = true
	mods_btn.tooltip_text = "Stub -- mod selection isn't built yet."
	col.add_child(mods_btn)

	col.add_child(_label("Grid", 26))
	var grid_row := HBoxContainer.new()
	grid_row.add_theme_constant_override("separation", 16)
	_width_box = _spin_box(1, 20)
	_height_box = _spin_box(2, 30)
	_kill_box = _spin_box(0, 29)
	_spawn_box = _spin_box(0, 29)
	grid_row.add_child(_labeled(_width_box, "W"))
	grid_row.add_child(_labeled(_height_box, "H"))
	grid_row.add_child(_labeled(_kill_box, "Kill row"))
	grid_row.add_child(_labeled(_spawn_box, "Spawn row"))
	col.add_child(grid_row)

	var apply_btn := Button.new()
	apply_btn.text = "Apply grid (resets the board)"
	apply_btn.pressed.connect(_on_apply_grid)
	col.add_child(apply_btn)

	var save_btn := Button.new()
	save_btn.text = "Save game state"
	save_btn.disabled = true
	save_btn.tooltip_text = "Stub -- format not decided yet."
	col.add_child(save_btn)

	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	col.add_child(restart_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(func() -> void: _show_page(_root_page))
	col.add_child(back_btn)

	return col


# --------------------------------------------------------------- ui helpers

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.TEXT)
	return l

func _spin_box(lo: int, hi: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.custom_minimum_size = Vector2(140.0, 0.0)
	return s

func _labeled(control: Control, caption: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_child(_label(caption, 20))
	v.add_child(control)
	return v

## A caption label + HSlider pair, added to `col`; returns the slider so the
## caller wires its own value_changed.
func _labeled_slider(col: VBoxContainer, caption: String, lo: float, hi: float) -> HSlider:
	col.add_child(_label(caption, 24))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1.0
	s.custom_minimum_size = Vector2(600.0, 32.0)
	col.add_child(s)
	return s
