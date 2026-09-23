extends Node
## Settings -- persisted user preferences (autoload), unlike `Debug` (session-
## only) or `Cfg`/`GameRules` (shipped/mod defaults, not user prefs). Loaded
## once at startup, saved to `user://settings.cfg` on every change.

signal changed

const SAVE_PATH := "user://settings.cfg"

## Uniform scale applied to HUD / pause-menu / debug-overlay root Controls.
## Not a Godot content-scale-factor change -- the design resolution and its
## canvas_items/expand stretch are unaffected; this only zooms the UI layer.
var ui_scale: float = 1.0
## 0..1. Not consumed by anything yet -- no screen shake exists (ROADMAP's
## "Juice" row is still unchecked). Plumbed now so that work has a setting to
## read from day one instead of retrofitting one later.
var screen_shake_strength: float = 1.0
## 0..1 linear slider values, applied to the "SFX" / "Music" audio buses
## (see audio/bus_layout.tres). No sound assets exist yet either, but the
## buses are real and the sliders already move their volume.
var sfx_volume: float = 1.0
var music_volume: float = 1.0

func _ready() -> void:
	_load()

func set_ui_scale(v: float) -> void:
	ui_scale = clampf(v, 0.5, 2.0)
	_save_and_notify()

func set_screen_shake_strength(v: float) -> void:
	screen_shake_strength = clampf(v, 0.0, 1.0)
	_save_and_notify()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume("SFX", sfx_volume)
	_save_and_notify()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume("Music", music_volume)
	_save_and_notify()

func _save_and_notify() -> void:
	_save()
	changed.emit()

## Silence rather than a very negative dB value at 0 -- linear_to_db(0) is
## -inf, which is correct but noisy to reason about; muting the bus directly
## is the same result and reads clearly in the audio panel.
func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.0001)
	if linear > 0.0001:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		ui_scale = cfg.get_value("settings", "ui_scale", ui_scale)
		screen_shake_strength = cfg.get_value("settings", "screen_shake_strength", screen_shake_strength)
		sfx_volume = cfg.get_value("settings", "sfx_volume", sfx_volume)
		music_volume = cfg.get_value("settings", "music_volume", music_volume)
	_apply_bus_volume("SFX", sfx_volume)
	_apply_bus_volume("Music", music_volume)

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "ui_scale", ui_scale)
	cfg.set_value("settings", "screen_shake_strength", screen_shake_strength)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.save(SAVE_PATH)
