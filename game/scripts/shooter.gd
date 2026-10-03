class_name Shooter
extends Node2D
## The aim line. 0 degrees is straight up, positive is clockwise (to the right).

var rules: GameRules
var aim_degrees: float = 0.0
var active: bool = true
## Shots left to fire this round, drawn as "×N" beside the launcher so the
## ball count reads as ammo (playtest 10/01). 0 hides it.
var ammo: int = 0:
	set(v):
		if v != ammo:
			ammo = v
			queue_redraw()
## +1 pickups caught this round, not yet added to `ammo`. Shown as "+N".
var pending_ammo: int = 0:
	set(v):
		if v != pending_ammo:
			pending_ammo = v
			queue_redraw()

const AMMO_FONT_SIZE := 34
## Gap from the launcher's centre to the near edge of the "×N" text.
const AMMO_OFFSET_X := 44.0
const PENDING_AMMO_COLOR := Color("#7dff6a")

func _ready() -> void:
	Skins.changed.connect(queue_redraw)

func setup(r: GameRules) -> void:
	rules = r
	queue_redraw()

func aim_direction() -> Vector2:
	return Vector2.UP.rotated(deg_to_rad(aim_degrees))

## Cosmetic slide to a new X, used when the round hands the shooter to
## wherever the first ball landed -- an instant snap read as a glitch.
func slide_to_x(x: float, duration: float) -> void:
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "position:x", x, duration)

func nudge(degrees: float) -> void:
	set_aim(aim_degrees + degrees)

func set_aim(degrees: float) -> void:
	var limit := rules.max_aim_degrees if rules else 78.0
	var clamped := clampf(degrees, -limit, limit)
	if not is_equal_approx(clamped, aim_degrees):
		aim_degrees = clamped
		queue_redraw()

## Point the line at a world position, respecting the clamp. Used by mouse aim.
func aim_at(world_point: Vector2) -> void:
	var to_point := world_point - global_position
	if to_point.length_squared() < 4.0:
		return
	set_aim(rad_to_deg(Vector2.UP.angle_to(to_point)))

## The angle to a world position with NO clamp applied -- used to tell a
## release that's genuinely past max_aim_degrees (cancel the shot) from one
## that just landed on the clamp (still a valid, if maxed-out, shot).
func raw_aim_degrees(world_point: Vector2) -> float:
	return rad_to_deg(Vector2.UP.angle_to(world_point - global_position))

## Muzzle flash length, seconds (Orbital Probe Cannon only).
const FLASH_SECONDS := 0.12

var _flash: float = 0.0

## A shot just left. Only the probe cannon shows it.
func flash() -> void:
	if Skins.launcher().shape != Skins.LauncherShape.PROBE_CANNON:
		return
	_flash = FLASH_SECONDS
	set_process(true)

func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()
	if _flash <= 0.0:
		set_process(false)

func _draw() -> void:
	match Skins.launcher().shape:
		Skins.LauncherShape.CANNON:
			_draw_cannon()
		Skins.LauncherShape.PROBE_CANNON:
			var dir := aim_direction() if active else Vector2.UP
			draw_probe_cannon(self, Vector2.ZERO, dir, 1.0, _flash / FLASH_SECONDS, active)
		_:
			_draw_ball_launcher()
	_draw_ammo()

## "×N  +P" beside the launcher, on whichever side has more room -- at a wall
## the far side would run off the board.
func _draw_ammo() -> void:
	if ammo <= 0 and pending_ammo <= 0:
		return
	var font := ThemeDB.fallback_font
	var main := "×%d" % ammo if ammo > 0 else ""
	var extra := ("  +%d" if main != "" else "+%d") % pending_ammo if pending_ammo > 0 else ""
	var main_w := font.get_string_size(main, HORIZONTAL_ALIGNMENT_LEFT, -1, AMMO_FONT_SIZE).x
	var extra_w := font.get_string_size(extra, HORIZONTAL_ALIGNMENT_LEFT, -1, AMMO_FONT_SIZE).x
	var on_right := global_position.x < get_viewport_rect().size.x * 0.5
	var x := AMMO_OFFSET_X if on_right else -AMMO_OFFSET_X - main_w - extra_w
	var baseline := AMMO_FONT_SIZE * 0.35
	var color := Skins.ball().ui_color()
	draw_string(font, Vector2(x, baseline), main, HORIZONTAL_ALIGNMENT_LEFT, -1, AMMO_FONT_SIZE, color)
	draw_string(font, Vector2(x + main_w, baseline), extra, HORIZONTAL_ALIGNMENT_LEFT, -1, AMMO_FONT_SIZE,
		PENDING_AMMO_COLOR)

## The Orbital Probe Cannon: a long segmented barrel with three ring bands
## and a glowing muzzle, on a heavy base. Static so the skin swatches can
## draw the same thing small. `flash` 0..1 is the muzzle flare.
static func draw_probe_cannon(c: CanvasItem, at: Vector2, dir: Vector2, scale: float,
		flash: float = 0.0, lit: bool = true) -> void:
	var dim := 1.0 if lit else 0.6
	var hull := Color("#8a7a5c").darkened(1.0 - dim)
	var hull_dark := Color("#3b342a").darkened(1.0 - dim)
	var band := Color("#c9a86a").darkened(1.0 - dim)
	var glow := Color("#9fe3ff")
	var perp := dir.orthogonal()

	c.draw_circle(at, 30.0 * scale, hull_dark)
	c.draw_circle(at, 22.0 * scale, hull)
	var length := 70.0 * scale
	var half_w := 11.0 * scale
	var tip := at + dir * length
	c.draw_colored_polygon(PackedVector2Array([
		at + perp * half_w, at - perp * half_w, tip - perp * half_w * 0.8, tip + perp * half_w * 0.8,
	]), hull)
	for f in [0.35, 0.6, 0.85]:
		var p: Vector2 = at + dir * length * f
		var w := half_w * 1.35
		c.draw_line(p + perp * w, p - perp * w, band, 5.0 * scale)
	c.draw_circle(tip, half_w * 0.75, Color(glow, 0.5 + 0.5 * dim))
	if flash > 0.0:
		c.draw_circle(tip + dir * 8.0 * scale, half_w * (1.2 + 1.5 * flash), Color(glow, flash))
	if lit:
		for i in range(2, 16):
			var alpha := clampf(0.7 - float(i) * 0.045, 0.05, 0.7)
			c.draw_circle(tip + dir * (float(i) * 34.0 * scale), 4.0 * scale, Color(glow, alpha))

func _draw_ball_launcher() -> void:
	var base := Skins.ball().color
	draw_circle(Vector2.ZERO, 22.0, base if active else base.darkened(0.5))
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, Palette.WALL.lightened(0.3), 3.0, true)
	if active:
		_draw_aim_dots(aim_direction(), Skins.ball().ui_color())

## The dotted aim line every non-probe launcher shares. It starts two dots
## out, which clears both the ball launcher's ring and the cannon's barrel tip.
func _draw_aim_dots(dir: Vector2, color: Color) -> void:
	for i in range(2, 20):
		var alpha := clampf(0.85 - float(i) * 0.04, 0.05, 0.85)
		draw_circle(dir * (float(i) * 36.0), 5.0, Color(color.r, color.g, color.b, alpha))

## A simple vector cannon -- deliberately plain, mostly to prove the launcher
## itself can be a skin category and not just the ball's colour. A base
## disc, a barrel polygon rotated to the aim direction, and a muzzle ring in
## the ball skin's accent colour.
func _draw_cannon() -> void:
	var accent := Skins.ball().color
	var dim := 1.0 if active else 0.6
	var metal := Color("#4b5563").darkened(1.0 - dim)
	var metal_dark := Color("#242830").darkened(1.0 - dim)

	draw_circle(Vector2.ZERO, 26.0, metal_dark)
	draw_circle(Vector2.ZERO, 20.0, metal)

	var dir := aim_direction() if active else Vector2.UP
	var perp := dir.orthogonal()
	var barrel_len := 50.0
	var half_w := 15.0
	var tip := dir * barrel_len
	var p1 := perp * half_w
	var p2 := -perp * half_w
	var points := PackedVector2Array([p1, p2, p2 + tip, p1 + tip])
	draw_colored_polygon(points, metal)
	draw_polyline(PackedVector2Array([p1, p1 + tip, p2 + tip, p2, p1]), metal_dark, 2.0, true)
	draw_circle(tip, half_w * 0.85, Color(accent.r, accent.g, accent.b, dim))
	# Playtest 10/01: with no line, players couldn't tell where it was aimed.
	if active:
		_draw_aim_dots(dir, Skins.ball().ui_color())
