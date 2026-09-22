class_name HUD
extends CanvasLayer
## Round number, ball count, damage this shot cycle, damage overall.

@onready var _round: Label = $Root/RoundLabel
@onready var _balls: Label = $Root/BallsLabel
@onready var _round_damage: Label = $Root/RoundDamageLabel
@onready var _total_damage: Label = $Root/TotalDamageLabel
@onready var _hint: Label = $Root/HintLabel
@onready var _game_over: Label = $Root/GameOverLabel

func refresh(round_number: int, balls: int, pending: int, round_damage: int, total_damage: int) -> void:
	_round.text = "ROUND %d" % round_number
	_balls.text = "BALLS %d" % balls + ("  (+%d)" % pending if pending > 0 else "")
	_round_damage.text = "THIS SHOT  %d" % round_damage
	_total_damage.text = "TOTAL  %d" % total_damage

func show_game_over(round_number: int, total_damage: int) -> void:
	_game_over.text = "GAME OVER\nround %d  ·  %d damage\n\npress R to restart" % [round_number, total_damage]
	_game_over.visible = true
	_hint.visible = false
