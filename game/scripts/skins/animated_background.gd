class_name AnimatedBackground
extends Node2D
## Base for animated background skins: a full-screen node Game adds behind
## the playfield (show_behind_parent) instead of its flat fill. One file per
## background under scripts/skins/backgrounds/, registered in
## Skins.background_skins.
##
## Two reactions, both no-ops by default: `on_board_cleared` when the last
## block on the board is destroyed, `on_new_ball` when a +1 pickup's dropped
## ball lands. Game forwards both; the Asset Viewer fires them on demand.

var view := Vector2.ZERO
var t: float = 0.0

func _ready() -> void:
	show_behind_parent = true
	view = NeonUI.view_size()

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func on_board_cleared(_pos: Vector2) -> void:
	pass

func on_new_ball(_pos: Vector2) -> void:
	pass
