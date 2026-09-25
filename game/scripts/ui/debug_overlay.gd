extends CanvasLayer
class_name DebugOverlay
## Visible only while Debug.enabled: per-row clear buttons, a hold-to-fill
## clear-all button, an on-screen D-pad (with a center shift-toggle for
## touch, since a touchscreen has no modifier key), and the ball-count /
## level "(expected N)" readouts.
##
## The D-pad presses the SAME named input actions the keyboard does
## (Input.action_press/release), so Game._tick_debug_input has exactly one
## input path regardless of source -- this file only ever touches Input
## state and Game's public debug_* methods, never Game's private fields.
##
## NOT verified on real touch hardware -- no touch/Android build exists yet
## (docs/ROADMAP.md still lists that as unscheduled). Built to spec; treat
## the two-finger-tap and on-screen D-pad feel as unverified until someone
## tries it on an actual device.

const HOLD_TO_CLEAR_SECONDS := 1.2

## True while the on-screen center '+' button is toggled on -- the touch
## stand-in for holding a physical Shift key. Game._tick_debug_input ORs this
## with Input.is_action_pressed("debug_shift_hold").
var touch_shift_toggled: bool = false

var _game: Game
var _ui_root: Control
var _row_button_root: Control
var _row_buttons: Array[Button] = []
var _ball_label: Label
var _round_label: Label
var _clear_all_progress: ProgressBar
var _clear_all_held: bool = false
var _clear_all_t: float = 0.0

func _ready() -> void:
	layer = 5
	_game = get_parent() as Game
	_build_ui()
	Debug.enabled_changed.connect(_on_debug_enabled_changed)
	Settings.changed.connect(_apply_ui_scale)
	_apply_ui_scale()
	# Row buttons are NOT built here: this _ready runs before Game's, so the
	# grid has no layout yet. Game._ready calls refresh_row_buttons() once the
	# playfield exists.
	visible = Debug.enabled

func _apply_ui_scale() -> void:
	_ui_root.scale = Vector2.ONE * Settings.ui_scale

func _on_debug_enabled_changed(value: bool) -> void:
	visible = value
	if value:
		refresh_row_buttons()
		refresh_readouts()

func refresh_readouts() -> void:
	if not visible:
		return
	_ball_label.text = "BALLS %d" % _game.ball_count
	if _game.expected_ball_count != _game.ball_count:
		_ball_label.text += "  (expected %d)" % _game.expected_ball_count
	_round_label.text = "LEVEL %d" % _game.round_number
	if _game.expected_round_number != _game.round_number:
		_round_label.text += "  (expected %d)" % _game.expected_round_number

func _process(delta: float) -> void:
	if not visible or not _clear_all_held:
		return
	_clear_all_t += delta
	_clear_all_progress.value = (_clear_all_t / HOLD_TO_CLEAR_SECONDS) * 100.0
	if _clear_all_t >= HOLD_TO_CLEAR_SECONDS:
		_clear_all_held = false
		_clear_all_t = 0.0
		_clear_all_progress.value = 0.0
		_game.debug_clear_all()

## Called whenever the grid's shape changes (init, or a debug grid-size
## apply) -- row count and cell geometry may both be different afterward.
func refresh_row_buttons() -> void:
	for b in _row_buttons:
		b.queue_free()
	_row_buttons.clear()
	var grid: GridManager = _game.grid
	for row in range(_game.rules.grid_height):
		var btn := Button.new()
		btn.text = "X"
		btn.custom_minimum_size = Vector2(48.0, 48.0)
		btn.position = Vector2(
			grid.origin.x + float(_game.rules.grid_width) * grid.cell_size + 12.0,
			grid.cell_center(0, row).y - 24.0
		)
		btn.pressed.connect(func() -> void: _game.debug_clear_row(row))
		_row_button_root.add_child(btn)
		_row_buttons.append(btn)

func _build_ui() -> void:
	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.pivot_offset = Vector2.ZERO
	add_child(_ui_root)
	var root := _ui_root

	_row_button_root = Control.new()
	_row_button_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_row_button_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_row_button_root)

	_ball_label = _readout_label(44.0, 200.0)
	_round_label = _readout_label(44.0, 236.0)
	root.add_child(_ball_label)
	root.add_child(_round_label)

	_build_clear_all_button(root)
	_build_dpad(root)

func _readout_label(x: float, y: float) -> Label:
	var l := Label.new()
	l.position = Vector2(x, y)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color("#ff8a65"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_clear_all_button(root: Control) -> void:
	var btn := Button.new()
	btn.text = "HOLD\nCLEAR ALL"
	btn.custom_minimum_size = Vector2(160.0, 160.0)
	btn.position = Vector2(44.0, 1636.0)
	btn.button_down.connect(func() -> void: _clear_all_held = true)
	btn.button_up.connect(func() -> void:
		_clear_all_held = false
		_clear_all_t = 0.0
		_clear_all_progress.value = 0.0)
	root.add_child(btn)

	_clear_all_progress = ProgressBar.new()
	_clear_all_progress.position = Vector2(44.0, 1802.0)
	_clear_all_progress.custom_minimum_size = Vector2(160.0, 20.0)
	_clear_all_progress.max_value = 100.0
	_clear_all_progress.show_percentage = false
	root.add_child(_clear_all_progress)

## A '+' shaped 3x3 grid: up/down/left/right around a center shift toggle.
func _build_dpad(root: Control) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(844.0, 1614.0)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	root.add_child(grid)

	grid.add_child(_spacer())
	grid.add_child(_dpad_button("^", "debug_up"))
	grid.add_child(_spacer())
	grid.add_child(_dpad_button("<", "debug_left"))
	grid.add_child(_shift_toggle_button())
	grid.add_child(_dpad_button(">", "debug_right"))
	grid.add_child(_spacer())
	grid.add_child(_dpad_button("v", "debug_down"))
	grid.add_child(_spacer())

func _spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(64.0, 64.0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Presses the same named action a keyboard press would -- Game does not know
## or care which source fired it.
func _dpad_button(caption: String, action: StringName) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.custom_minimum_size = Vector2(64.0, 64.0)
	btn.button_down.connect(func() -> void: Input.action_press(action))
	btn.button_up.connect(func() -> void: Input.action_release(action))
	return btn

func _shift_toggle_button() -> Button:
	var btn := Button.new()
	btn.text = "+"
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(64.0, 64.0)
	btn.toggled.connect(func(pressed: bool) -> void: touch_shift_toggled = pressed)
	return btn
