extends Node
## Unlocks -- earned progress (autoload), saved to `user://unlocks.cfg` on
## every change. A sixth lifetime: persisted like `Settings`, but progress
## rather than preferences, so resetting one never touches the other.
##
## Mods (`GameMod.locked_by`) and skins (`locked_by` on each skin record)
## name an unlock id; they're pickable once `is_unlocked(id)`.

signal changed

const SAVE_PATH := "user://unlocks.cfg"

## The title-screen constellation's reward: Wormholes, Time Rewind, and the
## Interloper / Orbital Probe Cannon / End Times skins.
const OUTER_WILDS := &"outer_wilds"

## Every id the game knows about, for the Debug Menu's Unlock all.
const ALL: Array[StringName] = [OUTER_WILDS]

var _unlocked: Dictionary = {} ## StringName -> true

func _ready() -> void:
	_load()

func is_unlocked(id: StringName) -> bool:
	return id == &"" or _unlocked.has(id)

func unlock(id: StringName) -> void:
	if _unlocked.has(id):
		return
	_unlocked[id] = true
	_save_and_notify()

func unlock_all() -> void:
	for id in ALL:
		_unlocked[id] = true
	_save_and_notify()

## Forget one unlock (the Debug Menu's Outer Wilds reset).
func relock(id: StringName) -> void:
	if not _unlocked.has(id):
		return
	_unlocked.erase(id)
	_save_and_notify()

func relock_all() -> void:
	_unlocked.clear()
	_save_and_notify()

func _save_and_notify() -> void:
	var cfg := ConfigFile.new()
	for id: StringName in _unlocked:
		cfg.set_value("unlocks", str(id), true)
	cfg.save(SAVE_PATH)
	changed.emit()

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK or not cfg.has_section("unlocks"):
		return
	for key in cfg.get_section_keys("unlocks"):
		if cfg.get_value("unlocks", key, false):
			_unlocked[StringName(key)] = true
