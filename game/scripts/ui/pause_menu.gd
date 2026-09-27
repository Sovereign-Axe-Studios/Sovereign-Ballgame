extends CanvasLayer
class_name PauseMenu
## The pause menu: a centred neon panel over a faint geometric backdrop.
## Root page (Resume / Settings / Skins / Debug Menu / Main menu), each of the
## others its own page. Built in code rather than laid out in a .tscn -- see
## docs/HANDOFF.md §7 on why hand-written scene UI is the riskiest part of
## this project, and Playfield.build_walls for the existing precedent.
##
## `process_mode = ALWAYS` (set in _ready) so this keeps taking input while
## `get_tree().paused` is true -- that IS the pause menu's job.

signal grid_apply_requested(width: int, height: int, kill_row: int, spawn_row: int)

const PANEL_SIZE := Vector2(920.0, 1720.0)

var _game: Game
var _ui_root: Control
var _root_page: Control
var _settings_page: Control
var _debug_page: Control
var _skins_page: Control
var _mods_page: Control
var _active_mods: ActiveModsPanel
var _current_page: Control

var _mode_label: Label
var _debug_toggle: Button
var _debug_explainer: Label
var _invincible_toggle: Button
var _width_box: SpinBox
var _height_box: SpinBox
var _kill_box: SpinBox
var _spawn_box: SpinBox
var _frag_cols_min: SpinBox
var _frag_cols_max: SpinBox
var _frag_rows_min: SpinBox
var _frag_rows_max: SpinBox
var _return_mode_option: OptionButton

const DEBUG_EXPLAINER_TEXT := "While on: click/tap a block for 1 damage, Shift+click or a two-finger tap destroys it outright. ↑↓ change ball count, Shift+↑↓ shifts the whole field up/down a row. ←→ (held) move the shooter, Shift+←→ changes the level. Row-clear buttons and a hold-to-clear-all button appear over the playfield during play."

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_game = get_parent() as Game
	_build_ui()
	Settings.changed.connect(_apply_ui_scale)
	_apply_ui_scale()
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

## Scales around the screen centre, so a bigger/smaller UI stays centred.
func _apply_ui_scale() -> void:
	_ui_root.pivot_offset = NeonUI.view_size() * 0.5
	_ui_root.scale = Vector2.ONE * Settings.ui_scale

func _show_page(page: Control) -> void:
	_current_page = page
	for p: Control in [_root_page, _settings_page, _debug_page, _skins_page, _mods_page]:
		p.visible = p == page

func _sync_fields() -> void:
	_mode_label.text = _mode_summary()
	_active_mods.show_mods(_game.rules)
	_debug_toggle.set_pressed_no_signal(Debug.enabled)
	_debug_explainer.visible = Debug.enabled
	_invincible_toggle.set_pressed_no_signal(Debug.invincible)
	_width_box.value = _game.rules.grid_width
	_height_box.value = _game.rules.grid_height
	_kill_box.value = _game.rules.death_row()
	_spawn_box.value = _game.rules.spawn_row_index
	_frag_cols_min.value = _game.rules.fragment_cols_min
	_frag_cols_max.value = _game.rules.fragment_cols_max
	_frag_rows_min.value = _game.rules.fragment_rows_min
	_frag_rows_max.value = _game.rules.fragment_rows_max
	_return_mode_option.select(Skins.return_mode)

func _on_apply_grid() -> void:
	grid_apply_requested.emit(int(_width_box.value), int(_height_box.value), int(_kill_box.value), int(_spawn_box.value))
	_sync_fields()


# ------------------------------------------------------------------- layout

func _build_ui() -> void:
	# Layered back to front: dim, faint geometric backdrop, then the panel.
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var backdrop := GeometricBackdrop.new()
	backdrop.faint = true
	backdrop.fill_background = false
	add_child(backdrop)

	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_ui_root)
	var panel: PanelContainer = NeonUI.modal(_ui_root, PANEL_SIZE, NeonUI.view_size(), 0.0)[1]

	# All pages share the panel; only one is ever visible.
	var stack := Control.new()
	panel.add_child(stack)
	_root_page = _page(_build_root_page)
	_settings_page = _page(_build_settings_page)
	_debug_page = _page(_build_debug_page)
	_skins_page = _page(_build_skins_page)
	_mods_page = _page(_build_mods_page)
	for p in [_root_page, _settings_page, _debug_page, _skins_page, _mods_page]:
		stack.add_child(p)

## A NeonUI page whose column `build` fills.
func _page(build: Callable) -> Control:
	var parts := NeonUI.page(0.0, 0)
	build.call(parts[1])
	return parts[0]

func _build_root_page(col: VBoxContainer) -> void:
	col.add_theme_constant_override("separation", 30)
	col.add_child(NeonUI.header("Paused"))
	_mode_label = NeonUI.label("", NeonUI.LABEL_FONT, NeonUI.TEXT_DIM)
	col.add_child(_mode_label)
	col.add_child(_spacer(30.0))

	var resume_btn := NeonUI.button("RESUME", true)
	resume_btn.pressed.connect(close)
	col.add_child(resume_btn)
	col.add_child(_nav_button("MODS", func() -> Control: return _mods_page))
	col.add_child(_nav_button("SETTINGS", func() -> Control: return _settings_page))
	col.add_child(_nav_button("SKINS", func() -> Control: return _skins_page))
	col.add_child(_nav_button("DEBUG MENU", func() -> Control: return _debug_page))

	var menu_btn := NeonUI.button("MAIN MENU")
	menu_btn.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	col.add_child(menu_btn)

func _build_settings_page(col: VBoxContainer) -> void:
	col.add_child(NeonUI.header("Settings"))
	col.add_child(SettingsPanel.new())
	col.add_child(_back_button())

## The run's mods, hover for details. Filled on open (see _sync_fields):
## this menu is built before Game installs them.
func _build_mods_page(col: VBoxContainer) -> void:
	col.add_child(NeonUI.header("Mods"))
	_active_mods = ActiveModsPanel.new()
	col.add_child(_active_mods)
	col.add_child(_back_button())

func _build_skins_page(col: VBoxContainer) -> void:
	col.add_child(NeonUI.header("Skins"))
	col.add_child(NeonUI.label("Session only -- click one to select it.", NeonUI.LABEL_FONT, NeonUI.TEXT_DIM))
	col.add_child(SkinsPanel.new())
	col.add_child(_back_button())

func _build_debug_page(col: VBoxContainer) -> void:
	col.add_child(NeonUI.header("Debug menu"))

	_debug_toggle = NeonUI.toggle("ENABLE DEBUG MODE")
	_debug_toggle.toggled.connect(func(pressed: bool) -> void:
		Debug.enabled = pressed
		_debug_explainer.visible = pressed)
	col.add_child(_debug_toggle)

	_debug_explainer = NeonUI.label(DEBUG_EXPLAINER_TEXT, 20, NeonUI.TEXT_DIM)
	_debug_explainer.visible = false
	col.add_child(_debug_explainer)

	_invincible_toggle = NeonUI.toggle("INVINCIBLE (AUTO-CLEAR A LETHAL ROW)")
	_invincible_toggle.toggled.connect(func(pressed: bool) -> void: Debug.invincible = pressed)
	col.add_child(_invincible_toggle)

	# Unlocks are persisted progress (the Unlocks autoload), so these write
	# user://unlocks.cfg. Pickers already built refresh on the next scene load.
	col.add_child(NeonUI.subheader("Outer Wilds egg"))
	var unlock_row := HBoxContainer.new()
	unlock_row.add_theme_constant_override("separation", 20)
	var unlock_btn := NeonUI.button("UNLOCK")
	unlock_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlock_btn.pressed.connect(func() -> void: Unlocks.unlock(Unlocks.OUTER_WILDS))
	unlock_row.add_child(unlock_btn)
	var relock_btn := NeonUI.button("RESET")
	relock_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relock_btn.tooltip_text = "Re-locks the extras and restores the unsolved constellation on the title screen."
	relock_btn.pressed.connect(func() -> void: Unlocks.relock(Unlocks.OUTER_WILDS))
	unlock_row.add_child(relock_btn)
	col.add_child(unlock_row)

	col.add_child(NeonUI.subheader("Ball return behaviour"))
	_return_mode_option = NeonUI.option_button()
	for mode in range(Skins.ReturnMode.size()):
		_return_mode_option.add_item(Skins.RETURN_MODE_NAMES[mode], mode)
	_return_mode_option.item_selected.connect(func(index: int) -> void:
		Skins.set_return_mode(_return_mode_option.get_item_id(index) as Skins.ReturnMode))
	col.add_child(_return_mode_option)

	col.add_child(NeonUI.subheader("Destroy fragments"))
	var frag_row := HBoxContainer.new()
	frag_row.add_theme_constant_override("separation", 16)
	_frag_cols_min = NeonUI.spin_box(1, 10)
	_frag_cols_max = NeonUI.spin_box(1, 10)
	_frag_rows_min = NeonUI.spin_box(1, 10)
	_frag_rows_max = NeonUI.spin_box(1, 10)
	_frag_cols_min.value_changed.connect(func(v: float) -> void: _game.rules.fragment_cols_min = int(v))
	_frag_cols_max.value_changed.connect(func(v: float) -> void: _game.rules.fragment_cols_max = int(v))
	_frag_rows_min.value_changed.connect(func(v: float) -> void: _game.rules.fragment_rows_min = int(v))
	_frag_rows_max.value_changed.connect(func(v: float) -> void: _game.rules.fragment_rows_max = int(v))
	frag_row.add_child(NeonUI.captioned(_frag_cols_min, "Cols min"))
	frag_row.add_child(NeonUI.captioned(_frag_cols_max, "Cols max"))
	frag_row.add_child(NeonUI.captioned(_frag_rows_min, "Rows min"))
	frag_row.add_child(NeonUI.captioned(_frag_rows_max, "Rows max"))
	col.add_child(frag_row)

	col.add_child(NeonUI.subheader("Grid"))
	var grid_row := HBoxContainer.new()
	grid_row.add_theme_constant_override("separation", 16)
	_width_box = NeonUI.spin_box(1, 20)
	_height_box = NeonUI.spin_box(2, 30)
	_kill_box = NeonUI.spin_box(0, 29)
	_spawn_box = NeonUI.spin_box(0, 29)
	grid_row.add_child(NeonUI.captioned(_width_box, "W"))
	grid_row.add_child(NeonUI.captioned(_height_box, "H"))
	grid_row.add_child(NeonUI.captioned(_kill_box, "Kill row"))
	grid_row.add_child(NeonUI.captioned(_spawn_box, "Spawn row"))
	col.add_child(grid_row)

	var apply_btn := NeonUI.button("APPLY GRID (RESETS THE BOARD)")
	apply_btn.pressed.connect(_on_apply_grid)
	col.add_child(apply_btn)

	var save_btn := NeonUI.button("SAVE GAME STATE")
	save_btn.disabled = true
	save_btn.tooltip_text = "Stub -- format not decided yet."
	col.add_child(save_btn)

	var restart_btn := NeonUI.button("RESTART")
	restart_btn.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	col.add_child(restart_btn)

	col.add_child(_back_button())


# --------------------------------------------------------------- ui helpers

## "Mode: Tilt -- Spread, 15° Tilt, Wrap Around". Read on open, not at build
## time: this menu is built before Game._ready installs the mods.
func _mode_summary() -> String:
	var names: Array[String] = []
	for mod in _game.rules.active_mods():
		names.append(mod.display_name)
	var mods := ", ".join(names) if not names.is_empty() else "no mods"
	return "Mode: %s -- %s" % [Run.mode_name, mods]

## `target` is a Callable because the pages don't exist yet while the root
## page is being built.
func _nav_button(text: String, target: Callable) -> Button:
	var b := NeonUI.button(text)
	b.pressed.connect(func() -> void:
		_sync_fields()
		_show_page(target.call()))
	return b

func _back_button() -> Button:
	var b := NeonUI.button("BACK")
	b.pressed.connect(func() -> void: _show_page(_root_page))
	return b

func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, height)
	return c
