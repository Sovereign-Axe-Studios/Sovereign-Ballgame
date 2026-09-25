class_name HUD
extends CanvasLayer
## Round number, ball count, damage this shot cycle, damage overall.

@onready var _ui_root: Control = $Root
@onready var _round: Label = $Root/RoundLabel
@onready var _balls: Label = $Root/BallsLabel
@onready var _round_damage: Label = $Root/RoundDamageLabel
@onready var _total_damage: Label = $Root/TotalDamageLabel
@onready var _hint: Label = $Root/HintLabel
@onready var _game_over: Label = $Root/GameOverLabel

## Mod status lines ("LIVES 2"), under the ball count. Built in code rather
## than added to main.tscn -- it's empty unless a mod has something to say.
var _status: Label

func _ready() -> void:
	_ui_root.pivot_offset = Vector2.ZERO
	_status = Label.new()
	_status.position = Vector2(44.0, 190.0)
	_status.size = Vector2(576.0, 48.0)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_size_override("font_size", 34)
	_status.add_theme_color_override("font_color", Color(0.957, 0.447, 0.714))
	_ui_root.add_child(_status)
	Settings.changed.connect(_apply_ui_scale)
	_apply_ui_scale()

func _apply_ui_scale() -> void:
	_ui_root.scale = Vector2.ONE * Settings.ui_scale

func refresh(round_number: int, balls: int, pending: int, round_damage: int, total_damage: int,
		status_lines: Array[String] = []) -> void:
	_status.text = "   ".join(status_lines)
	_round.text = "ROUND %d" % round_number
	_balls.text = "BALLS %d" % balls + ("  (+%d)" % pending if pending > 0 else "")
	_round_damage.text = "THIS SHOT  %d" % round_damage
	_total_damage.text = "TOTAL  %d" % total_damage

func show_game_over(round_number: int, total_damage: int) -> void:
	_game_over.text = "GAME OVER\nround %d  ·  %d damage\n\npress R to restart" % [round_number, total_damage]
	_game_over.visible = true
	_hint.visible = false
