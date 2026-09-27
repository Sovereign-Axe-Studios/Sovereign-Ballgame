class_name AssetViewer
extends Node2D
## Browses what the project actually has right now, in tabs: Skins (a live
## SkinPreview -- ball rolling, background running, its reactions on buttons
## -- above the shared SkinsPanel), Modes (ball-return behaviour, and every registered
## game mod), Audio (SFX/Music volume plus the sound library exported from the
## Ballgame Sound Lab: audition everything and pick what the game plays; see AudioLib).
##
## Deliberately NOT padded out to match a richer reference screen from
## another Sovereign Axe title -- every tab reflects what this project
## actually contains today.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const MARGIN := 40.0

var _return_mode_option: OptionButton

func _ready() -> void:
	# Quiet the menu music so auditions are heard on their own; the main menu restarts it.
	AudioLib.stop_music(0.3)
	add_child(GeometricBackdrop.new())
	_build_ui()

func _exit_tree() -> void:
	AudioLib.stop_preview()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var vp := NeonUI.view_size()
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var header := NeonUI.header("Asset viewer")
	header.position = Vector2(MARGIN, 40.0)
	header.size = Vector2(vp.x - MARGIN * 2.0 - 220.0, 80.0)
	root.add_child(header)

	var back_btn := NeonUI.button("BACK")
	back_btn.position = Vector2(vp.x - MARGIN - 200.0, 40.0)
	back_btn.size = Vector2(200.0, NeonUI.BUTTON_HEIGHT)
	back_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU_SCENE))
	root.add_child(back_btn)

	var tabs := TabContainer.new()
	tabs.position = Vector2(MARGIN, 170.0)
	tabs.size = Vector2(vp.x - MARGIN * 2.0, vp.y - 210.0)
	_style_tabs(tabs)
	root.add_child(tabs)

	tabs.add_child(_tab("Skins", func(col: VBoxContainer) -> void:
		var preview := SkinPreview.new()
		col.add_child(preview)
		# The big preview above follows hover, so no second inline one.
		var panel := SkinsPanel.new(false)
		panel.background_hovered.connect(preview.show_background)
		col.add_child(panel)))
	tabs.add_child(_tab("Modes", _build_modes_tab))
	tabs.add_child(_tab("Audio", _build_audio_tab))

func _style_tabs(tabs: TabContainer) -> void:
	tabs.add_theme_font_size_override("font_size", 30)
	tabs.add_theme_stylebox_override("panel", NeonUI.panel_style())
	var off := NeonUI.box(false, NeonUI.CYAN, 0.0)
	var on := NeonUI.box(true, NeonUI.CYAN, 0.0)
	tabs.add_theme_stylebox_override("tab_unselected", off)
	tabs.add_theme_stylebox_override("tab_hovered", on)
	tabs.add_theme_stylebox_override("tab_selected", on)
	tabs.add_theme_color_override("font_selected_color", NeonUI.TEXT)
	tabs.add_theme_color_override("font_unselected_color", NeonUI.TEXT_SOFT)
	tabs.add_theme_color_override("font_hovered_color", NeonUI.TEXT)

## A named NeonUI page whose column `build` fills.
func _tab(title: String, build: Callable) -> Control:
	var parts := NeonUI.page(0.0, 0)
	var scroll: ScrollContainer = parts[0]
	scroll.name = title
	build.call(parts[1])
	return scroll


# --------------------------------------------------------------- modes tab

func _build_modes_tab(col: VBoxContainer) -> void:
	col.add_child(NeonUI.subheader("Ball return behaviour"))
	_return_mode_option = NeonUI.option_button()
	for mode in range(Skins.ReturnMode.size()):
		_return_mode_option.add_item(Skins.RETURN_MODE_NAMES[mode], mode)
	_return_mode_option.select(Skins.return_mode)
	_return_mode_option.item_selected.connect(func(index: int) -> void:
		Skins.set_return_mode(_return_mode_option.get_item_id(index) as Skins.ReturnMode))
	col.add_child(_return_mode_option)

	col.add_child(NeonUI.subheader("Game mods"))
	for script: GDScript in Cfg.MODS:
		var mod := script.new() as GameMod
		var locked := not Unlocks.is_unlocked(mod.locked_by)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		var icon := ModPreviewIcon.new(mod, locked)
		icon.custom_minimum_size = Vector2(96.0, 96.0)
		row.add_child(icon)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := "???" if locked else mod.display_name
		text.add_child(NeonUI.label("%s  ·  %s" % [title, GameMod.category_name(mod.category)], 26, NeonUI.TEXT))
		text.add_child(NeonUI.label(Skins.LOCKED_HINT if locked else mod.description, 20, NeonUI.TEXT_DIM))
		row.add_child(text)
		if not locked:
			row.mouse_entered.connect(func() -> void: icon.playing = true)
			row.mouse_exited.connect(func() -> void: icon.playing = false)
			row.mouse_filter = Control.MOUSE_FILTER_PASS
		col.add_child(row)


# --------------------------------------------------------------- audio tab

func _build_audio_tab(col: VBoxContainer) -> void:
	var sfx := NeonUI.slider_row(col, "SFX volume", 0.0, 100.0)
	sfx.value = Settings.sfx_volume * 100.0
	sfx.value_changed.connect(func(v: float) -> void: Settings.set_sfx_volume(v / 100.0))
	var music := NeonUI.slider_row(col, "Music volume", 0.0, 100.0)
	music.value = Settings.music_volume * 100.0
	music.value_changed.connect(func(v: float) -> void: Settings.set_music_volume(v / 100.0))

	if not AudioLib.has_library():
		col.add_child(NeonUI.label("No sound library found. Export one from the Ballgame Sound Lab (Export game library), unzip it so the library folder ends up in game/audio/, let Godot import it, then reopen this screen.", 22, NeonUI.TEXT_DIM))
		return
	_build_audio_picks(col)
	_build_audio_browser(col)

## One row per place the game plays a sound, each with a dropdown of the
## versions that fit it. Changing a dropdown saves the pick and auditions it.
func _build_audio_picks(col: VBoxContainer) -> void:
	col.add_child(NeonUI.subheader("Your picks for this session"))
	col.add_child(NeonUI.label("What the game plays. Saved between runs. Picking one plays it once so you can hear it.", 22, NeonUI.TEXT_DIM))

	# Game music comes in five tiers, one per ten rounds; auditions use this one.
	var tier_opt := NeonUI.option_button()
	for t in range(1, AudioLib.MAX_TIER + 1):
		tier_opt.add_item("Tier %d" % t)
	tier_opt.select(AudioLib.preview_tier - 1)
	tier_opt.item_selected.connect(func(idx: int) -> void: AudioLib.preview_tier = idx + 1)
	tier_opt.set_meta("no_ui_sound", true)
	col.add_child(NeonUI.captioned(tier_opt, "Game music audition tier"))

	var options := {} # hook key -> OptionButton, so Reset can re-point them
	for h in AudioLib.HOOKS:
		var key: String = h["key"]
		var list: Array = AudioLib.entries_for(key)
		if list.is_empty():
			continue
		var opt := NeonUI.option_button()
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opt.set_meta("no_ui_sound", true)
		var current: String = AudioLib.pick_entry(key).get("id", "")
		for i in range(list.size()):
			opt.add_item(_entry_label(list[i], h["kind"] == "music"))
			opt.set_item_metadata(i, list[i]["id"])
			if list[i]["id"] == current:
				opt.select(i)
		opt.item_selected.connect(func(idx: int) -> void:
			var id: String = opt.get_item_metadata(idx)
			AudioLib.set_pick(key, id)
			AudioLib.preview(id))
		options[key] = opt

		var play := _audition_button("▶")
		play.custom_minimum_size.x = 90.0
		play.pressed.connect(func() -> void:
			_toggle_preview(opt.get_item_metadata(opt.selected)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(opt)
		row.add_child(play)
		col.add_child(NeonUI.captioned(row, h["label"]))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	col.add_child(actions)
	var stop := _audition_button("■ Stop")
	stop.pressed.connect(AudioLib.stop_preview)
	actions.add_child(stop)
	var reset := _audition_button("Reset picks to defaults")
	reset.pressed.connect(func() -> void:
		AudioLib.stop_preview()
		AudioLib.reset_picks()
		for key: String in options:
			var opt: OptionButton = options[key]
			var id: String = AudioLib.pick_entry(key).get("id", "")
			for i in range(opt.item_count):
				if opt.get_item_metadata(i) == id:
					opt.select(i))
	actions.add_child(reset)

## Every sound in the library, grouped, for listening. Sounds the game does
## not use yet (abilities, milestones, mods) can still be auditioned here.
func _build_audio_browser(col: VBoxContainer) -> void:
	col.add_child(NeonUI.subheader("Library"))
	col.add_child(NeonUI.label("Press a sound to hear it, press it again to stop.", 22, NeonUI.TEXT_DIM))
	var groups: Array[String] = []
	var by_group := {}
	for e in AudioLib.entries:
		var g := "%s: %s" % ["Music" if e["kind"] == "music" else "Sound effects", e["category"]]
		if not by_group.has(g):
			by_group[g] = []
			groups.append(g)
		by_group[g].append(e)
	for g in groups:
		col.add_child(NeonUI.label(g, 26, NeonUI.TEXT))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		col.add_child(flow)
		for e in by_group[g]:
			var id: String = e["id"]
			var b := _audition_button(_entry_label(e, true))
			b.pressed.connect(func() -> void: _toggle_preview(id))
			flow.add_child(b)

## "Attract Mode" for an original, "Attract Mode A: Layer by layer" for a variation.
## Effects drop the name because the row's caption already says it.
func _entry_label(e: Dictionary, with_name: bool) -> String:
	var base: String = e["name"] if with_name else ""
	if e["original"]:
		return base if with_name else "Original"
	var v := "%s: %s" % [e["variant"], e["label"]]
	return "%s %s" % [base, v] if with_name else v

func _toggle_preview(id: String) -> void:
	if AudioLib.is_previewing(id):
		AudioLib.stop_preview()
	else:
		AudioLib.preview(id)

## Audition buttons already play what they audition, so they skip the UI click.
func _audition_button(text: String) -> Button:
	var b := NeonUI.chip(text)
	b.set_meta("no_ui_sound", true)
	return b
