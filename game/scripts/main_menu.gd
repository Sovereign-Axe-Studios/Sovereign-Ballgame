class_name MainMenu
extends Node2D
## Title screen: Quick Play / Play / Skins / Settings / States (stub) / Asset
## Viewer / Quit, over the neon GeometricBackdrop and a sparse starfield -- the
## Nomai constellation easter egg hides among the stars.
## Quick Play starts a no-mods run immediately; Play opens Mode Select.
##
## Built in code, no .tscn UI -- consistent with every other screen in this
## project (see docs/HANDOFF.md §7). Settings and Skins are in-place overlays
## (the shared SettingsPanel / SkinsPanel); Asset Viewer is a separate scene,
## since it's a full browsing screen, not a dialog. States is a stub -- there's
## no save-state system yet.
##
## States and Asset Viewer only exist in a Debug build (Build.shows_dev_screens).
## Under the subtitle, the build's DesignationLine types out which build this is;
## the version sits in the bottom-right corner.

const MODE_SELECT_SCENE := "res://scenes/mode_select.tscn"
const ASSET_VIEWER_SCENE := "res://scenes/asset_viewer.tscn"
const STAR_COUNT := 120
const BUTTON_WIDTH := 640.0
## Top of the two-line title; the subtitle and buttons hang below it.
const TITLE_Y := 250.0
const TITLE_LINE_STEP := 118.0
const OVERLAY_SIZE := Vector2(940.0, 1500.0)
## Designation line text colour per Build.Mode: hazard red for Debug, amber for
## the playtest build, the title's own cyan for Release.
const DESIGNATION_COLORS := {
	Build.Mode.DEBUG: Color("#ff5a6e"),
	Build.Mode.LIMITED: Color("#f0b84f"),
	Build.Mode.RELEASE: NeonUI.CYAN,
}

var _stars: Array[Dictionary] = [] ## {pos: Vector2, radius: float, phase: float}
var _t: float = 0.0

var _root: Control
var _layer: CanvasLayer
var _title_lines: Array[Label] = []
var _overlay: Control

func _ready() -> void:
	randomize()
	var vp := NeonUI.view_size()
	for i in range(STAR_COUNT):
		_stars.append({
			"pos": Vector2(randf_range(0.0, vp.x), randf_range(0.0, vp.y)),
			"radius": randf_range(1.0, 2.4),
			"phase": randf_range(0.0, TAU),
		})
	# Behind this node's own _draw (the stars), which is behind the
	# constellation, which is behind the UI layer.
	var backdrop := GeometricBackdrop.new()
	backdrop.show_behind_parent = true
	add_child(backdrop)
	var constellation := NomaiConstellation.new()
	add_child(constellation)
	constellation.completed.connect(_on_constellation_completed)
	_build_ui()
	AudioLib.play_menu_music()

func _process(delta: float) -> void:
	_t += delta
	# A slow neon breathe on the title.
	var glow := 0.35 + 0.25 * sin(_t * 1.4)
	for line in _title_lines:
		line.add_theme_color_override("font_outline_color", Color(NeonUI.MAGENTA, glow))
	queue_redraw()

func _draw() -> void:
	for star in _stars:
		var alpha: float = 0.3 + 0.3 * sin(_t * 1.6 + star.phase)
		draw_circle(star.pos, star.radius, Color(1, 1, 1, clampf(alpha, 0.08, 0.7)))

## Esc closes an open overlay.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _overlay != null:
		_close_overlay()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------- layout

func _build_ui() -> void:
	var vp := NeonUI.view_size()
	_layer = CanvasLayer.new()
	add_child(_layer)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)

	# Two single-line labels: a multi-line Label spaces its lines far apart
	# at this size.
	for i in range(2):
		var line := Label.new()
		line.text = ["SOVEREIGN", "BALLGAME"][i]
		line.position = Vector2(0.0, TITLE_Y + i * TITLE_LINE_STEP)
		line.size = Vector2(vp.x, 140.0)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_font_size_override("font_size", 104)
		line.add_theme_color_override("font_color", NeonUI.CYAN)
		line.add_theme_constant_override("outline_size", 18)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(line)
		_title_lines.append(line)

	var subtitle := NeonUI.label("A BALLZ-STYLE BRICK BREAKER", 28, NeonUI.TEXT_SOFT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0.0, TITLE_Y + TITLE_LINE_STEP * 2.0 + 10.0)
	subtitle.size = Vector2(vp.x, 50.0)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(subtitle)
	var designation := DesignationLine.new(Build.designation_of(Build.mode()), DESIGNATION_COLORS[Build.mode()])
	designation.position = Vector2(0.0, TITLE_Y + TITLE_LINE_STEP * 2.0 + 64.0)
	designation.size = Vector2(vp.x, 40.0)
	_root.add_child(designation)

	var version := NeonUI.label("v" + Build.version(), 20, NeonUI.TEXT_DIM)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -300.0
	version.offset_top = -56.0
	version.offset_right = -24.0
	version.offset_bottom = -20.0
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(version)

	var button_col := VBoxContainer.new()
	# Below the constellation's area: a button over a star would swallow the
	# click (and start a game) instead of lighting it.
	var buttons_y := NomaiConstellation.AREA.end.y + 50.0
	button_col.position = Vector2((vp.x - BUTTON_WIDTH) * 0.5, buttons_y)
	button_col.size = Vector2(BUTTON_WIDTH, 0.0)
	button_col.add_theme_constant_override("separation", 28)
	_root.add_child(button_col)

	var quick_btn := NeonUI.button("QUICK PLAY", true)
	quick_btn.pressed.connect(func() -> void: Run.start("Quick Play", []))
	button_col.add_child(quick_btn)

	var play_btn := NeonUI.button("PLAY")
	play_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file(MODE_SELECT_SCENE))
	button_col.add_child(play_btn)

	var skins_btn := NeonUI.button("SKINS")
	skins_btn.pressed.connect(func() -> void: _open_overlay("Skins", SkinsPanel.new()))
	button_col.add_child(skins_btn)

	var settings_btn := NeonUI.button("SETTINGS")
	settings_btn.pressed.connect(func() -> void: _open_overlay("Settings", SettingsPanel.new()))
	button_col.add_child(settings_btn)

	if Build.shows_dev_screens():
		var states_btn := NeonUI.button("GAME STATES")
		states_btn.disabled = true
		states_btn.tooltip_text = "Stub -- no save-state system yet (see the Debug Menu's Save game state stub)."
		button_col.add_child(states_btn)

		var viewer_btn := NeonUI.button("ASSET VIEWER")
		viewer_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file(ASSET_VIEWER_SCENE))
		button_col.add_child(viewer_btn)

	if _can_quit():
		var quit_btn := NeonUI.button("QUIT")
		quit_btn.pressed.connect(func() -> void: get_tree().quit())
		button_col.add_child(quit_btn)

## No QUIT on the web (quit() does nothing in a browser tab) or on iOS (Apple
## rejects apps that close themselves -- the home gesture is the exit).
static func _can_quit() -> bool:
	return not (OS.has_feature("web") or OS.has_feature("ios"))

## A centred neon modal: title, `content` in a scrolling column, BACK.
func _open_overlay(title: String, content: Control) -> void:
	_close_overlay()
	var parts := NeonUI.modal(_layer, OVERLAY_SIZE, NeonUI.view_size(), 0.75)
	_overlay = parts[0]
	var page := NeonUI.page(0.0, 0)
	(parts[1] as PanelContainer).add_child(page[0])
	var col: VBoxContainer = page[1]
	col.add_child(NeonUI.header(title))
	col.add_child(content)
	var back := NeonUI.button("BACK")
	back.pressed.connect(_close_overlay)
	col.add_child(back)

func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null

# ------------------------------------------------------ Outer Wilds unlock

## Saved the moment the last star lights (so quitting mid-reveal still keeps
## it); the reveal opens as the constellation's bloom peaks.
func _on_constellation_completed() -> void:
	Unlocks.unlock(Unlocks.OUTER_WILDS)
	await get_tree().create_timer(NomaiConstellation.BLOOM_SECONDS * 0.5).timeout
	_layer.add_child(OuterWildsReveal.new())
