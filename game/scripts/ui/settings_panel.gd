class_name SettingsPanel
extends VBoxContainer
## The Settings controls, shared by the pause menu and the title screen (they
## used to be built twice). Writes straight to the `Settings` autoload, and
## re-reads it whenever it becomes visible, so two copies never disagree.

var _ui_scale: HSlider
var _shake: HSlider
var _sfx: HSlider
var _music: HSlider
var _grid: Button
var _grid_thickness: HSlider

func _init() -> void:
	add_theme_constant_override("separation", 18)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_ui_scale = NeonUI.slider_row(self, "UI scale", 50.0, 200.0)
	_ui_scale.value_changed.connect(func(v: float) -> void: Settings.set_ui_scale(v / 100.0))

	_shake = NeonUI.slider_row(self, "Screen shake strength (not used yet)", 0.0, 100.0)
	_shake.value_changed.connect(func(v: float) -> void: Settings.set_screen_shake_strength(v / 100.0))

	_sfx = NeonUI.slider_row(self, "SFX volume", 0.0, 100.0)
	_sfx.value_changed.connect(func(v: float) -> void: Settings.set_sfx_volume(v / 100.0))

	_music = NeonUI.slider_row(self, "Music volume", 0.0, 100.0)
	_music.value_changed.connect(func(v: float) -> void: Settings.set_music_volume(v / 100.0))

	_grid = NeonUI.toggle("Show background grid")
	_grid.toggled.connect(func(pressed: bool) -> void: Settings.set_show_background_grid(pressed))
	add_child(_grid)

	_grid_thickness = NeonUI.slider_row(self, "Background grid line thickness", 0.5, 4.0, 0.5)
	_grid_thickness.value_changed.connect(func(v: float) -> void: Settings.set_grid_line_thickness(v))

	visibility_changed.connect(sync)

func _ready() -> void:
	sync()

## Pull the current values from Settings.
func sync() -> void:
	if not is_visible_in_tree() and is_inside_tree():
		return
	_ui_scale.set_value_no_signal(Settings.ui_scale * 100.0)
	_shake.set_value_no_signal(Settings.screen_shake_strength * 100.0)
	_sfx.set_value_no_signal(Settings.sfx_volume * 100.0)
	_music.set_value_no_signal(Settings.music_volume * 100.0)
	_grid.set_pressed_no_signal(Settings.show_background_grid)
	_grid_thickness.set_value_no_signal(Settings.grid_line_thickness)
