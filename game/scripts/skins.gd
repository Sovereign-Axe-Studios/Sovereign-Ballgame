extends Node
## Skins -- a handful of alternate ball / background / block colour
## treatments, for quick side-by-side comparison from the Debug Menu.
##
## Dev-facing test swatches, not shipped content: no unlocks, no art assets
## (there aren't any yet), no persistence -- session-only like `Debug`, not
## `Settings`, since "which swatch was I looking at" isn't worth remembering
## across a restart.

signal changed

class BallSkin:
	var skin_name: String
	var color: Color
	var highlight: Color
	func _init(n: String, c: Color, h: Color) -> void:
		skin_name = n
		color = c
		highlight = h

class BackgroundSkin:
	var skin_name: String
	var color: Color
	func _init(n: String, c: Color) -> void:
		skin_name = n
		color = c

class BlockSkin:
	var skin_name: String
	var ramp: Array[Color]
	func _init(n: String, r: Array[Color]) -> void:
		skin_name = n
		ramp = r

var ball_skins: Array[BallSkin] = [
	BallSkin.new("Classic", Palette.BALL, Color(1, 1, 1, 0.55)),
	BallSkin.new("Neon Cyan", Color("#22d3ee"), Color(1, 1, 1, 0.6)),
	BallSkin.new("Magma", Color("#ff6b35"), Color("#ffe08a")),
	BallSkin.new("Violet", Color("#a78bfa"), Color(1, 1, 1, 0.55)),
]

var background_skins: Array[BackgroundSkin] = [
	BackgroundSkin.new("Void", Palette.BACKGROUND),
	BackgroundSkin.new("Indigo Night", Color("#161129")),
	BackgroundSkin.new("Deep Forest", Color("#0f1a14")),
	BackgroundSkin.new("Crimson Dusk", Color("#1a1013")),
]

## Each ramp is read the same way Palette.ROYGBIV was: low health at index 0,
## full health at the last index, lerped between neighbours.
var block_skins: Array[BlockSkin] = [
	BlockSkin.new("ROYGBIV", Palette.ROYGBIV),
	BlockSkin.new("Ice to Fire", [
		Color("#1e88e5"), Color("#22d3ee"), Color("#f5f7fa"),
		Color("#fdd835"), Color("#fb8c00"), Color("#e53935"),
	] as Array[Color]),
	BlockSkin.new("Mono Teal", [
		Color("#083344"), Color("#0e7490"), Color("#22d3ee"), Color("#a5f3fc"),
	] as Array[Color]),
	BlockSkin.new("Neon Sunset", [
		Color("#ff4d8d"), Color("#ff8a5c"), Color("#ffd23f"),
	] as Array[Color]),
]

var ball_index: int = 0
var background_index: int = 0
var block_index: int = 0

func ball() -> BallSkin:
	return ball_skins[ball_index]

func background() -> BackgroundSkin:
	return background_skins[background_index]

func block() -> BlockSkin:
	return block_skins[block_index]

func cycle_ball() -> void:
	ball_index = (ball_index + 1) % ball_skins.size()
	changed.emit()

func cycle_background() -> void:
	background_index = (background_index + 1) % background_skins.size()
	changed.emit()

func cycle_block() -> void:
	block_index = (block_index + 1) % block_skins.size()
	changed.emit()
