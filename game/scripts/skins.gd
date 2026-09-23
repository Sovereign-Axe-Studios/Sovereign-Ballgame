extends Node
## Skins -- a handful of alternate ball / background / block / launcher
## visuals, and a few ball-return behaviour variants, all for quick
## side-by-side comparison from the pause menu's Skins page (visuals) and
## Debug Menu (ball-return mode).
##
## Dev-facing test variants, not shipped content: no unlocks, no art assets
## (there aren't any yet), no persistence -- session-only like `Debug`, not
## `Settings`, since "which one was I comparing" isn't worth remembering
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

## What Shooter._draw() renders. Not a colour swap like the others -- BALL and
## CANNON are genuinely different vector shapes, so this is an enum rather
## than a data record; Shooter branches on it directly.
enum LauncherShape { BALL, CANNON }

class LauncherSkin:
	var skin_name: String
	var shape: LauncherShape
	func _init(n: String, s: LauncherShape) -> void:
		skin_name = n
		shape = s

## How a landed ball behaves before the next round starts. STICK_* keep it
## frozen where it landed until the round fully resolves, then move it;
## MOVE_TO_SHOOTER and LINE_UP move it the instant it lands instead. See
## Game._on_ball_finished / _end_round for where each branch is handled.
enum ReturnMode {
	STICK_ALL_AT_ONCE,
	STICK_ORDERED,
	STICK_RANDOM,
	MOVE_TO_SHOOTER,
	LINE_UP,
}

const RETURN_MODE_NAMES := {
	ReturnMode.STICK_ALL_AT_ONCE: "Stick, then all move at once",
	ReturnMode.STICK_ORDERED: "Stick, then move in landing order",
	ReturnMode.STICK_RANDOM: "Stick, then move in random order",
	ReturnMode.MOVE_TO_SHOOTER: "Move to shooter immediately",
	ReturnMode.LINE_UP: "Line up immediately",
}

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

var launcher_skins: Array[LauncherSkin] = [
	LauncherSkin.new("Ball", LauncherShape.BALL),
	LauncherSkin.new("Cannon", LauncherShape.CANNON),
]

var ball_index: int = 0
var background_index: int = 0
var block_index: int = 0
var launcher_index: int = 0
var return_mode: ReturnMode = ReturnMode.STICK_ALL_AT_ONCE

func ball() -> BallSkin:
	return ball_skins[ball_index]

func background() -> BackgroundSkin:
	return background_skins[background_index]

func block() -> BlockSkin:
	return block_skins[block_index]

func launcher() -> LauncherSkin:
	return launcher_skins[launcher_index]

func return_mode_name() -> String:
	return RETURN_MODE_NAMES[return_mode]

func cycle_ball() -> void:
	set_ball(ball_index + 1)

func cycle_background() -> void:
	set_background(background_index + 1)

func cycle_block() -> void:
	set_block(block_index + 1)

func cycle_launcher() -> void:
	set_launcher(launcher_index + 1)

func cycle_return_mode() -> void:
	set_return_mode(((return_mode + 1) % ReturnMode.size()) as ReturnMode)

## Direct-selection setters -- the Skins page picks a specific swatch by its
## own button rather than only stepping through them one at a time.
func set_ball(index: int) -> void:
	ball_index = posmod(index, ball_skins.size())
	changed.emit()

func set_background(index: int) -> void:
	background_index = posmod(index, background_skins.size())
	changed.emit()

func set_block(index: int) -> void:
	block_index = posmod(index, block_skins.size())
	changed.emit()

func set_launcher(index: int) -> void:
	launcher_index = posmod(index, launcher_skins.size())
	changed.emit()

func set_return_mode(mode: ReturnMode) -> void:
	return_mode = mode
	changed.emit()
