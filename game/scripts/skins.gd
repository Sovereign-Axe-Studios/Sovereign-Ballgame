extends Node
## Skins -- a handful of alternate ball / background / block / launcher
## visuals, and a few ball-return behaviour variants, all for quick
## side-by-side comparison from the pause menu's Skins page (visuals) and
## Debug Menu (ball-return mode).
##
## Every look is drawn in code (no art assets): ball looks in
## scripts/skins/balls/, animated backgrounds in scripts/skins/backgrounds/.
## The SELECTION is session-only like `Debug`, not `Settings`, since "which
## one was I comparing" isn't worth remembering across a restart. A few skins
## are earned: `locked_by` names an `Unlocks` id, and a locked skin can't be
## selected through any setter.

signal changed

## Shown in pickers in place of a locked skin's name.
const LOCKED_NAME := "???"
const LOCKED_HINT := "Look to the stars."

## Ball looks: one file each under scripts/skins/balls/ (see BallLook).
## Add a look = a file + a line here. The basic colours are plain BallLooks.
const BALL_LOOKS: Array[GDScript] = [
	preload("res://scripts/skins/balls/beach_ball.gd"),
	preload("res://scripts/skins/balls/planet.gd"),
	preload("res://scripts/skins/balls/disco_ball.gd"),
	preload("res://scripts/skins/balls/marble.gd"),
	preload("res://scripts/skins/balls/eight_ball.gd"),
	preload("res://scripts/skins/balls/golf_ball.gd"),
	preload("res://scripts/skins/balls/basketball.gd"),
	preload("res://scripts/skins/balls/meteor.gd"),
	preload("res://scripts/skins/balls/snowball.gd"),
	preload("res://scripts/skins/balls/pearl.gd"),
	preload("res://scripts/skins/balls/apple.gd"),
	preload("res://scripts/skins/balls/interloper.gd"),
]

## Plain-colour balls, listed first in the picker. "Classic" is the default.
const BASIC_COLORS := {
	"Classic": Color("#eceff1"), "Red": Color("#e53935"), "Orange": Color("#fb8c00"),
	"Yellow": Color("#fdd835"), "Green": Color("#43a047"), "Cyan": Color("#22d3ee"),
	"Blue": Color("#1e88e5"), "Purple": Color("#8e24aa"), "Pink": Color("#ec4899"),
	"Charcoal": Color("#37474f"),
}

class BackgroundSkin extends SkinRecord:
	## Flat fill, and the tint menus read.
	var color: Color
	## An AnimatedBackground script Game instances behind the playfield in
	## place of the flat fill. null = flat.
	var scene: GDScript
	func _init(n: String, c: Color, s: GDScript = null, lock: StringName = &"") -> void:
		skin_name = n
		color = c
		scene = s
		locked_by = lock

class BlockSkin extends SkinRecord:
	var ramp: Array[Color]
	func _init(n: String, r: Array[Color]) -> void:
		skin_name = n
		ramp = r

## What Shooter._draw() renders. Not a colour swap like the others -- BALL and
## CANNON are genuinely different vector shapes, so this is an enum rather
## than a data record; Shooter branches on it directly.
enum LauncherShape { BALL, CANNON, PROBE_CANNON }

class LauncherSkin extends SkinRecord:
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

var ball_skins: Array[BallLook] = _build_ball_looks()

var background_skins: Array[BackgroundSkin] = [
	BackgroundSkin.new("Void", Palette.BACKGROUND),
	BackgroundSkin.new("Indigo Night", Color("#161129")),
	BackgroundSkin.new("Deep Forest", Color("#0f1a14")),
	BackgroundSkin.new("Crimson Dusk", Color("#1a1013")),
	BackgroundSkin.new("Synthwave", Color("#1a0b2e"), preload("res://scripts/skins/backgrounds/synthwave.gd")),
	BackgroundSkin.new("Arcade", Color("#050510"), preload("res://scripts/skins/backgrounds/arcade.gd")),
	BackgroundSkin.new("Mosaic", Color("#0d1a2a"), preload("res://scripts/skins/backgrounds/mosaic.gd")),
	BackgroundSkin.new("Geometric", NeonUI.BG, preload("res://scripts/skins/backgrounds/geometric.gd")),
	BackgroundSkin.new("Aurora", Color("#040a14"), preload("res://scripts/skins/backgrounds/aurora.gd")),
	BackgroundSkin.new("Lava Lamp", Color("#1c0b12"), preload("res://scripts/skins/backgrounds/lava_lamp.gd")),
	BackgroundSkin.new("End Times", Color("#06080c"), preload("res://scripts/skins/backgrounds/end_times.gd"),
		Unlocks.OUTER_WILDS),
]

static func _build_ball_looks() -> Array[BallLook]:
	var out: Array[BallLook] = []
	for n: String in BASIC_COLORS:
		out.append(BallLook.new(n, BASIC_COLORS[n]))
	for script in BALL_LOOKS:
		out.append(script.new() as BallLook)
	return out

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
	_probe_cannon(),
]

# --- Outer Wilds extras (unlocked by the title-screen constellation) --------
# (The Interloper ball and End Times background are registered above.)

static func _probe_cannon() -> LauncherSkin:
	var s := LauncherSkin.new("Orbital Probe Cannon", LauncherShape.PROBE_CANNON)
	s.locked_by = Unlocks.OUTER_WILDS
	return s

var ball_index: int = 0
var background_index: int = 0
var block_index: int = 0
var launcher_index: int = 0
var return_mode: ReturnMode = ReturnMode.STICK_ALL_AT_ONCE

func ball() -> BallLook:
	return ball_skins[ball_index]

func background() -> BackgroundSkin:
	return background_skins[background_index]

func block() -> BlockSkin:
	return block_skins[block_index]

func launcher() -> LauncherSkin:
	return launcher_skins[launcher_index]

## Names for a picker: LOCKED_NAME in place of each locked skin's.
func picker_names(skins: Array) -> Array:
	return skins.map(func(s: SkinRecord) -> String: return LOCKED_NAME if s.is_locked() else s.skin_name)

## Reset any selection that's locked (e.g. after the Debug Menu's Re-lock).
func _on_unlocks_changed() -> void:
	if ball().is_locked():
		ball_index = 0
	if background().is_locked():
		background_index = 0
	if launcher().is_locked():
		launcher_index = 0
	changed.emit()

func _ready() -> void:
	Unlocks.changed.connect(_on_unlocks_changed)

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
	if ball_skins[posmod(index, ball_skins.size())].is_locked():
		return
	ball_index = posmod(index, ball_skins.size())
	changed.emit()

func set_background(index: int) -> void:
	if background_skins[posmod(index, background_skins.size())].is_locked():
		return
	background_index = posmod(index, background_skins.size())
	changed.emit()

func set_block(index: int) -> void:
	block_index = posmod(index, block_skins.size())
	changed.emit()

func set_launcher(index: int) -> void:
	if launcher_skins[posmod(index, launcher_skins.size())].is_locked():
		return
	launcher_index = posmod(index, launcher_skins.size())
	changed.emit()

func set_return_mode(mode: ReturnMode) -> void:
	return_mode = mode
	changed.emit()
