extends CanvasLayer
class_name PauseMenu
## The pause menu: Resume / Settings / Debug Menu / Skins / Main Menu on the
## root page, each of the latter three opening its own page. Built in code
## rather than laid out in a .tscn -- see docs/HANDOFF.md §7 on why
## hand-written scene UI is the riskiest part of this project, and
## Game._build_walls for the existing precedent.
##
## `process_mode = ALWAYS` (set in _ready) so this keeps taking input while
## `get_tree().paused` is true -- that IS the pause menu's job.

signal grid_apply_requested(width: int, height: int, kill_row: int, spawn_row: int)

const MARGIN := 36
const BUTTON_HEIGHT := 76.0
const BUTTON_FONT_SIZE := 32
const LABEL_FONT_SIZE := 24
const HEADER_FONT_SIZE := 48
const SUBHEADER_FONT_SIZE := 28

var _game: Game
var _ui_root: Control
var _root_page: Control
var _settings_page: Control
var _debug_page: Control
var _skins_page: Control
var _current_page: Control

var _debug_check: CheckBox
var _width_box: SpinBox
var _height_box: SpinBox
var _kill_box: SpinBox
var _spawn_box: SpinBox
var _frag_cols_min: SpinBox
var _frag_cols_max: SpinBox
var _frag_rows_min: SpinBox
var _frag_rows_max: SpinBox
var _return_mode_label: Label

var _ui_scale_slider: HSlider
var _shake_slider: HSlider
var _sfx_slider: HSlider
var _music_slider: HSlider
var _grid_check: CheckBox
var _grid_thickness_slider: HSlider

var _ball_skin_label: Label
var _background_skin_label: Label
var _block_skin_label: Label
var _launcher_skin_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_game = get_parent() as Game
	_build_ui()
	Settings.changed.connect(_apply_ui_scale)
	Skins.changed.connect(_sync_skin_labels)
	_apply_ui_scale()
	_sync_skin_labels()
	visible = false
	_show_page(_root_page)

## Escape backs out of a sub-page first, and only closes the menu from root
## -- matches how a modal settings/debug panel usually behaves elsewhere.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if not visible:
		open()
	elif _current_page != _root_page:
		_show_page(_root_page)
	else:
		close()
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
	_current_page = page
	_root_page.visible = page == _root_page
	_settings_page.visible = page == _settings_page
	_debug_page.visible = page == _debug_page
	_skins_page.visible = page == _skins_page

func _sync_fields() -> void:
	_debug_check.button_pressed = Debug.enabled
	_width_box.value = _game.rules.grid_width
	_height_box.value = _game.rules.grid_height
	_kill_box.value = _game.rules.death_row()
	_spawn_box.value = _game.rules.spawn_row_index
	_frag_cols_min.value = _game.rules.fragment_cols_min
	_frag_cols_max.value = _game.rules.fragment_cols_max
	_frag_rows_min.value = _game.rules.fragment_rows_min
	_frag_rows_max.value = _game.rules.fragment_rows_max
	_ui_scale_slider.value = Settings.ui_scale * 100.0
	_shake_slider.value = Settings.screen_shake_strength * 100.0
	_sfx_slider.value = Settings.sfx_volume * 100.0
	_music_slider.value = Settings.music_volume * 100.0
	_grid_check.button_pressed = Settings.show_background_grid
	_grid_thickness_slider.value = Settings.grid_line_thickness
	_sync_skin_labels()

func _sync_skin_labels() -> void:
	_ball_skin_label.text = "Ball: %s" % Skins.ball().skin_name
	_background_skin_label.text = "Background: %s" % Skins.background().skin_name
	_block_skin_label.text = "Block: %s" % Skins.block().skin_name
	_launcher_skin_label.text = "Launcher: %s" % Skins.launcher().skin_name
	_return_mode_label.text = "Ball return: %s" % Skins.return_mode_name()

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
	dim.color = Color(0, 0, 0, 0.65)
	_ui_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.position = Vector2(80.0, 140.0)
	panel.custom_minimum_size = Vector2(920.0, 1720.0)
	_ui_root.add_child(panel)

	# All pages share one full-rect area so only one is ever visible at once.
	var stack := Control.new()
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(stack)

	_root_page = _wrap_page(_build_root_page())
	_settings_page = _wrap_page(_build_settings_page())
	_debug_page = _wrap_page(_build_debug_page())
	_skins_page = _wrap_page(_build_skins_page())
	stack.add_child(_root_page)
	stack.add_child(_settings_page)
	stack.add_child(_debug_page)
	stack.add_child(_skins_page)

## Margin on all four sides, and a scroll container in case a page's content
## (the Debug Menu especially) runs taller than the panel.
func _wrap_page(content: VBoxContainer) -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, MARGIN)

	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	scroll.add_child(margin)
	return scroll

func _page_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	return col

func _build_root_page() -> VBoxContainer:
	var col := _page_column()
	col.add_child(_header("PAUSED"))

	var resume_btn := _button("Resume", true)
	resume_btn.pressed.connect(close)
	col.add_child(resume_btn)

	var settings_btn := _button("Settings")
	settings_btn.pressed.connect(func() -> void:
		_sync_fields()
		_show_page(_settings_page))
	col.add_child(settings_btn)

	var debug_btn := _button("Debug Menu")
	debug_btn.pressed.connect(func() -> void:
		_sync_fields()
		_show_page(_debug_page))
	col.add_child(debug_btn)

	var skins_btn := _button("Skins")
	skins_btn.pressed.connect(func() -> void:
		_sync_skin_labels()
		_show_page(_skins_page))
	col.add_child(skins_btn)

	var menu_btn := _button("Main menu")
	menu_btn.disabled = true
	menu_btn.tooltip_text = "Stub -- there is no main menu scene yet."
	col.add_child(menu_btn)

	return col

func _build_settings_page() -> VBoxContainer:
	var col := _page_column()
	col.add_child(_header("SETTINGS"))

	_ui_scale_slider = _labeled_slider(col, "UI scale", 50.0, 200.0)
	_ui_scale_slider.value_changed.connect(func(v: float) -> void: Settings.set_ui_scale(v / 100.0))

	_shake_slider = _labeled_slider(col, "Screen shake strength (not consumed yet)", 0.0, 100.0)
	_shake_slider.value_changed.connect(func(v: float) -> void: Settings.set_screen_shake_strength(v / 100.0))

	_sfx_slider = _labeled_slider(col, "SFX volume", 0.0, 100.0)
	_sfx_slider.value_changed.connect(func(v: float) -> void: Settings.set_sfx_volume(v / 100.0))

	_music_slider = _labeled_slider(col, "Music volume", 0.0, 100.0)
	_music_slider.value_changed.connect(func(v: float) -> void: Settings.set_music_volume(v / 100.0))

	_grid_check = CheckBox.new()
	_grid_check.text = "Show background grid"
	_grid_check.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	_grid_check.toggled.connect(func(pressed: bool) -> void: Settings.set_show_background_grid(pressed))
	col.add_child(_grid_check)

	_grid_thickness_slider = _labeled_slider(col, "Background grid line thickness", 0.5, 4.0)
	_grid_thickness_slider.step = 0.5
	_grid_thickness_slider.value_changed.connect(func(v: float) -> void: Settings.set_grid_line_thickness(v))

	col.add_child(_back_button(_root_page))
	return col

func _build_skins_page() -> VBoxContainer:
	var col := _page_column()
	col.add_child(_header("SKINS"))
	col.add_child(_label("Test swatches, not persisted -- session only.", LABEL_FONT_SIZE))

	_ball_skin_label = _label("Ball: ?", LABEL_FONT_SIZE)
	col.add_child(_skin_preview_row(_ball_preview(), _ball_skin_label, func() -> void: Skins.cycle_ball()))

	_background_skin_label = _label("Background: ?", LABEL_FONT_SIZE)
	col.add_child(_skin_preview_row(_background_preview(), _background_skin_label, func() -> void: Skins.cycle_background()))

	_block_skin_label = _label("Block: ?", LABEL_FONT_SIZE)
	col.add_child(_skin_preview_row(_block_preview(), _block_skin_label, func() -> void: Skins.cycle_block()))

	_launcher_skin_label = _label("Launcher: ?", LABEL_FONT_SIZE)
	col.add_child(_skin_preview_row(_launcher_preview(), _launcher_skin_label, func() -> void: Skins.cycle_launcher()))

	col.add_child(_back_button(_root_page))
	return col

func _build_debug_page() -> VBoxContainer:
	var col := _page_column()
	col.add_child(_header("DEBUG MENU"))

	_debug_check = CheckBox.new()
	_debug_check.text = "Enable debug mode"
	_debug_check.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	_debug_check.toggled.connect(func(pressed: bool) -> void: Debug.enabled = pressed)
	col.add_child(_debug_check)

	col.add_child(_label("Change game mods", SUBHEADER_FONT_SIZE))
	var mods_btn := _button("Mods...")
	mods_btn.disabled = true
	mods_btn.tooltip_text = "Stub -- mod selection isn't built yet."
	col.add_child(mods_btn)

	col.add_child(_label("Ball return behaviour", SUBHEADER_FONT_SIZE))
	_return_mode_label = _label("Ball return: ?", LABEL_FONT_SIZE)
	var return_row := HBoxContainer.new()
	return_row.add_theme_constant_override("separation", 16)
	return_row.add_child(_return_mode_label)
	var return_cycle := _button("Cycle")
	return_cycle.pressed.connect(func() -> void: Skins.cycle_return_mode())
	return_row.add_child(return_cycle)
	col.add_child(return_row)

	col.add_child(_label("Destroy fragments", SUBHEADER_FONT_SIZE))
	var frag_row := HBoxContainer.new()
	frag_row.add_theme_constant_override("separation", 16)
	_frag_cols_min = _spin_box(1, 10)
	_frag_cols_max = _spin_box(1, 10)
	_frag_rows_min = _spin_box(1, 10)
	_frag_rows_max = _spin_box(1, 10)
	_frag_cols_min.value_changed.connect(func(v: float) -> void: _game.rules.fragment_cols_min = int(v))
	_frag_cols_max.value_changed.connect(func(v: float) -> void: _game.rules.fragment_cols_max = int(v))
	_frag_rows_min.value_changed.connect(func(v: float) -> void: _game.rules.fragment_rows_min = int(v))
	_frag_rows_max.value_changed.connect(func(v: float) -> void: _game.rules.fragment_rows_max = int(v))
	frag_row.add_child(_labeled(_frag_cols_min, "Cols min"))
	frag_row.add_child(_labeled(_frag_cols_max, "Cols max"))
	frag_row.add_child(_labeled(_frag_rows_min, "Rows min"))
	frag_row.add_child(_labeled(_frag_rows_max, "Rows max"))
	col.add_child(frag_row)

	col.add_child(_label("Grid", SUBHEADER_FONT_SIZE))
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

	var apply_btn := _button("Apply grid (resets the board)")
	apply_btn.pressed.connect(_on_apply_grid)
	col.add_child(apply_btn)

	var save_btn := _button("Save game state")
	save_btn.disabled = true
	save_btn.tooltip_text = "Stub -- format not decided yet."
	col.add_child(save_btn)

	var restart_btn := _button("Restart")
	restart_btn.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	col.add_child(restart_btn)

	col.add_child(_back_button(_root_page))
	return col


# --------------------------------------------------------------- ui helpers

func _header(text: String) -> Label:
	return _label(text, HEADER_FONT_SIZE)

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _button_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	return sb

## `primary` (Resume) gets an accent colour so the root page reads as one
## obvious default action plus three secondary ones, not four equal buttons.
func _button(text: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	b.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	var base := Color("#3949ab") if primary else Color("#2b3442")
	b.add_theme_stylebox_override("normal", _button_style(base))
	b.add_theme_stylebox_override("hover", _button_style(base.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", _button_style(base.darkened(0.15)))
	b.add_theme_stylebox_override("disabled", _button_style(base.darkened(0.5)))
	b.add_theme_color_override("font_color", Palette.TEXT)
	b.add_theme_color_override("font_disabled_color", Palette.TEXT_DIM)
	return b

func _back_button(target: Control) -> Button:
	var b := _button("Back")
	b.pressed.connect(func() -> void: _show_page(target))
	return b

func _spin_box(lo: int, hi: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.custom_minimum_size = Vector2(150.0, 56.0)
	s.get_line_edit().add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	return s

func _labeled(control: Control, caption: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_child(_label(caption, 18))
	v.add_child(control)
	return v

## A visual preview, its name label, and a "Cycle" button, stacked as one row.
func _skin_preview_row(preview: Control, name_label: Label, on_cycle: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.add_child(preview)
	name_label.custom_minimum_size = Vector2(260.0, 0.0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	var btn := _button("Cycle")
	btn.pressed.connect(on_cycle)
	row.add_child(btn)
	return row

## A caption label + HSlider pair, added to `col`; returns the slider so the
## caller wires its own value_changed.
func _labeled_slider(col: VBoxContainer, caption: String, lo: float, hi: float) -> HSlider:
	col.add_child(_label(caption, LABEL_FONT_SIZE))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1.0
	s.custom_minimum_size = Vector2(0.0, 40.0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(s)
	return s


# ------------------------------------------------------------- skin previews
# Each is a plain Control drawn via its own `draw` signal rather than a
## dedicated script -- there's nothing here that needs its own class, just a
## few pixels reacting to Skins.changed.

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
		if Skins.launcher().shape == Skins.LauncherShape.CANNON:
			c.draw_rect(Rect2(Vector2(center.x - 9.0, 6.0), Vector2(18.0, size.y - 26.0)), Color("#4b5563"), true)
			c.draw_circle(Vector2(center.x, size.y - 16.0), 18.0, Color("#242830"))
			c.draw_circle(Vector2(center.x, 10.0), 8.0, accent)
		else:
			c.draw_circle(center, size.x * 0.35, accent))
	Skins.changed.connect(c.queue_redraw)
	return c
