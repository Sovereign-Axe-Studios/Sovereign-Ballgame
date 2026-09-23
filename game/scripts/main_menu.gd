class_name MainMenu
extends Node2D
## Title screen: Play / Settings / States (stub) / Asset Viewer.
##
## Built in code, no .tscn UI -- consistent with every other screen in this
## project (see docs/HANDOFF.md §7). Settings is an in-place overlay (same
## show/hide pattern as PauseMenu's pages, since it's a quick "adjust and come
## right back"); Asset Viewer is a separate scene, since it's a full browsing
## screen, not a dialog. States is a stub -- there's no save-state system yet
## (see the Debug Menu's own "Save game state" stub).

const GAME_SCENE := "res://scenes/main.tscn"
const ASSET_VIEWER_SCENE := "res://scenes/asset_viewer.tscn"
const STAR_COUNT := 70

var _stars: Array[Dictionary] = [] ## {pos: Vector2, radius: float, phase: float}
var _blocks: Array[Dictionary] = [] ## {pos: Vector2, size: float, rot: float, speed: float}
var _t: float = 0.0

var _root: Control
var _settings_overlay: Control
var _ui_scale_slider: HSlider
var _shake_slider: HSlider
var _sfx_slider: HSlider
var _music_slider: HSlider
var _grid_toggle: Button
var _grid_thickness_slider: HSlider

func _ready() -> void:
	randomize()
	_build_background_data()
	_build_ui()

func _build_background_data() -> void:
	var vp := _viewport_size()
	for i in range(STAR_COUNT):
		_stars.append({
			"pos": Vector2(randf_range(0.0, vp.x), randf_range(0.0, vp.y)),
			"radius": randf_range(1.0, 2.6),
			"phase": randf_range(0.0, TAU),
		})
	for i in range(3):
		_blocks.append({
			"pos": Vector2(randf_range(0.15, 0.85) * vp.x, randf_range(0.1, 0.55) * vp.y),
			"size": randf_range(140.0, 260.0),
			"rot": randf_range(0.0, TAU),
			"speed": randf_range(-0.08, 0.08),
		})

func _process(delta: float) -> void:
	_t += delta
	for b in _blocks:
		b.rot += b.speed * delta
	queue_redraw()

func _viewport_size() -> Vector2:
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)

func _draw() -> void:
	var vp := _viewport_size()
	draw_rect(Rect2(Vector2.ZERO, vp), Skins.background().color.darkened(0.2), true)

	# A few large, dim, slowly-rotating squares in the current block skin's
	# colour -- a nod to what the game is about, not a literal scene replay.
	var ramp: Array[Color] = Skins.block().ramp
	for i in range(_blocks.size()):
		var b: Dictionary = _blocks[i]
		var color: Color = ramp[i % ramp.size()]
		color.a = 0.06
		var half: float = b.size * 0.5
		var corners := PackedVector2Array([
			Vector2(-half, -half).rotated(b.rot), Vector2(half, -half).rotated(b.rot),
			Vector2(half, half).rotated(b.rot), Vector2(-half, half).rotated(b.rot),
		])
		var offset: Vector2 = b.pos
		var points := PackedVector2Array()
		for c in corners:
			points.append(c + offset)
		draw_colored_polygon(points, color)

	for star in _stars:
		var pos: Vector2 = star.pos
		var alpha: float = 0.35 + 0.35 * sin(_t * 1.6 + star.phase)
		draw_circle(pos, star.radius, Color(1, 1, 1, clampf(alpha, 0.1, 0.85)))


# ------------------------------------------------------------------- layout

func _build_ui() -> void:
	var vp := _viewport_size()
	var layer := CanvasLayer.new()
	add_child(layer)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_root)

	var title := Label.new()
	title.text = "SOVEREIGN BALLGAME"
	title.position = Vector2(0.0, vp.y * 0.22)
	title.size = Vector2(vp.x, 120.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", Skins.ball().color)
	title.add_theme_color_override("font_outline_color", Color("#0a0d12"))
	title.add_theme_constant_override("outline_size", 10)
	_root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A BALLZ-STYLE BRICK BREAKER"
	subtitle.position = Vector2(0.0, vp.y * 0.22 + 128.0)
	subtitle.size = Vector2(vp.x, 60.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_root.add_child(subtitle)

	var button_col := VBoxContainer.new()
	button_col.position = Vector2(vp.x * 0.5 - 340.0, vp.y * 0.5)
	button_col.size = Vector2(680.0, 0.0)
	button_col.add_theme_constant_override("separation", 26)
	_root.add_child(button_col)

	var play_btn := _arcade_button("▶ PLAY")
	play_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file(GAME_SCENE))
	button_col.add_child(play_btn)

	var settings_btn := _arcade_button("⚙ SETTINGS")
	settings_btn.pressed.connect(_open_settings)
	button_col.add_child(settings_btn)

	var states_btn := _arcade_button("\U0001f4be STATES")
	states_btn.disabled = true
	states_btn.tooltip_text = "Stub -- no save-state system yet (see the Debug Menu's Save game state stub)."
	button_col.add_child(states_btn)

	var viewer_btn := _arcade_button("◆ ASSET VIEWER")
	viewer_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file(ASSET_VIEWER_SCENE))
	button_col.add_child(viewer_btn)

	_build_settings_overlay(layer, vp)

func _arcade_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, 92.0)
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_stylebox_override("normal", _arcade_style(false))
	b.add_theme_stylebox_override("hover", _arcade_style(true))
	b.add_theme_stylebox_override("pressed", _arcade_style(true))
	b.add_theme_stylebox_override("disabled", _arcade_disabled_style())
	b.add_theme_color_override("font_color", Skins.ball().color)
	b.add_theme_color_override("font_disabled_color", Palette.TEXT_DIM)
	return b

## Sharp corners + a neon border -- the pixelated-arcade look, distinct from
## the pause menu's rounded style so the title screen reads as its own place.
func _arcade_style(lit: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#12313a") if lit else Color("#0e1a20")
	sb.border_color = Skins.ball().color
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	return sb

func _arcade_disabled_style() -> StyleBoxFlat:
	var sb := _arcade_style(false)
	sb.border_color = Palette.TEXT_DIM
	sb.bg_color = Color("#0a0d12")
	return sb


# ------------------------------------------------------------ settings overlay

func _open_settings() -> void:
	_sync_settings_fields()
	_settings_overlay.visible = true

func _close_settings() -> void:
	_settings_overlay.visible = false

func _sync_settings_fields() -> void:
	_ui_scale_slider.value = Settings.ui_scale * 100.0
	_shake_slider.value = Settings.screen_shake_strength * 100.0
	_sfx_slider.value = Settings.sfx_volume * 100.0
	_music_slider.value = Settings.music_volume * 100.0
	_grid_toggle.button_pressed = Settings.show_background_grid
	_grid_thickness_slider.value = Settings.grid_line_thickness

func _build_settings_overlay(layer: CanvasLayer, vp: Vector2) -> void:
	_settings_overlay = Control.new()
	_settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.visible = false
	layer.add_child(_settings_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	_settings_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.position = Vector2(vp.x * 0.5 - 460.0, vp.y * 0.5 - 560.0)
	panel.custom_minimum_size = Vector2(920.0, 1120.0)
	_settings_overlay.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 36)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	margin.add_child(col)

	var header := Label.new()
	header.text = "SETTINGS"
	header.add_theme_font_size_override("font_size", 44)
	header.add_theme_color_override("font_color", Palette.TEXT)
	col.add_child(header)

	_ui_scale_slider = _slider_row(col, "UI scale", 50.0, 200.0)
	_ui_scale_slider.value_changed.connect(func(v: float) -> void: Settings.set_ui_scale(v / 100.0))

	_shake_slider = _slider_row(col, "Screen shake strength", 0.0, 100.0)
	_shake_slider.value_changed.connect(func(v: float) -> void: Settings.set_screen_shake_strength(v / 100.0))

	_sfx_slider = _slider_row(col, "SFX volume", 0.0, 100.0)
	_sfx_slider.value_changed.connect(func(v: float) -> void: Settings.set_sfx_volume(v / 100.0))

	_music_slider = _slider_row(col, "Music volume", 0.0, 100.0)
	_music_slider.value_changed.connect(func(v: float) -> void: Settings.set_music_volume(v / 100.0))

	_grid_toggle = _arcade_button("Show background grid")
	_grid_toggle.toggle_mode = true
	_grid_toggle.custom_minimum_size.y = 76.0
	_grid_toggle.toggled.connect(func(pressed: bool) -> void: Settings.set_show_background_grid(pressed))
	col.add_child(_grid_toggle)

	_grid_thickness_slider = _slider_row(col, "Background grid line thickness", 0.5, 4.0)
	_grid_thickness_slider.step = 0.5
	_grid_thickness_slider.value_changed.connect(func(v: float) -> void: Settings.set_grid_line_thickness(v))

	var back_btn := _arcade_button("BACK")
	back_btn.pressed.connect(_close_settings)
	col.add_child(back_btn)

func _slider_row(col: VBoxContainer, caption: String, lo: float, hi: float) -> HSlider:
	var l := Label.new()
	l.text = caption
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Palette.TEXT)
	col.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1.0
	s.custom_minimum_size = Vector2(0.0, 40.0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(s)
	return s
