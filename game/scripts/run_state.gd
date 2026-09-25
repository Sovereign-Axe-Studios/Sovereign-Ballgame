extends Node
## Run -- which mode this session is playing (autoload). Session-only, like
## `Debug`: the fifth lifetime alongside `Cfg` (shipped defaults), `Debug`
## (session flags), `Settings` (persisted prefs) and `Skins` (session test
## swatches).
##
## Holds mod SCRIPTS, not instances. `Game._ready` instantiates fresh ones for
## every run, so stateful mods (Lives) reset on an R restart while the mode
## itself carries over.

const GAME_SCENE := "res://scenes/main.tscn"

var mode_name: String = "Quick Play"
var mod_scripts: Array[GDScript] = []

## Set the mode and load the game.
func start(mode: String, mods: Array[GDScript]) -> void:
	mode_name = mode
	mod_scripts = mods.duplicate()
	get_tree().change_scene_to_file(GAME_SCENE)

## Fresh instances of this run's mods.
func make_mods() -> Array[GameMod]:
	var out: Array[GameMod] = []
	for script in mod_scripts:
		out.append(script.new() as GameMod)
	return out
