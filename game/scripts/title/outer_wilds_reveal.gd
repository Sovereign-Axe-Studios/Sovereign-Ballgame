class_name OuterWildsReveal
extends Control
## The Outer Wilds unlock moment, opened by MainMenu when the constellation
## completes. About five seconds, and a click skips to the end:
##   0.0-0.8  the screen dims
##   0.8-2.8  a glowing Nomai-style spiral of text writes itself outward
##   2.8-4.8  five reward cards flip in, each with a live preview
##   4.8+     CONTINUE fades in
## The unlock itself is saved before this opens, not after.

signal closed

## Original flavour text in the Nomai voice (not quoted from the game).
const TEXT := "YOU FOLLOWED THE OLD LIGHT BETWEEN THE STARS AND FOUND OUR MARK · WHAT WE LEFT WAITING IS YOURS NOW · EXPLORE ·"
const NOMAI_BLUE := Color("#9fd8ff")
const DIM_END := 0.8
const TEXT_START := 0.8
const TEXT_END := 2.8
const CARDS_START := 2.8
const CARD_STAGGER := 0.4
const CARD_FLIP := 0.35
const DONE_AT := 4.8
const CARD_SIZE := Vector2(184.0, 280.0)
const SPIRAL_CENTER := Vector2(540.0, 640.0)
## Archimedean spiral r = SPIRAL_A + SPIRAL_B * theta.
const SPIRAL_A := 40.0
const SPIRAL_B := 21.0
const SPIRAL_FONT := 30
## Arc length each character takes along the spiral, px.
const CHAR_STEP := 21.0

var _t: float = 0.0
var _cards: Array[Control] = []
var _continue: Button
var _title: Label
var _glyphs: Array[Dictionary] = []  ## {pos, angle, char}

func _ready() -> void:
	# Explicit, not anchors: under a CanvasLayer the anchors haven't resolved
	# by the first draw, and a zero-size overlay neither dims nor takes clicks.
	position = Vector2.ZERO
	size = NeonUI.view_size()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout_spiral()

	_title = NeonUI.label("OUTER WILDS EXTRAS UNLOCKED", 44, NOMAI_BLUE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0.0, 1110.0)
	_title.size = Vector2(1080.0, 60.0)
	_title.modulate.a = 0.0
	add_child(_title)

	var makers: Array[Callable] = [_interloper_card, _cannon_card, _end_times_card, _wormholes_card, _rewind_card]
	var names := ["Interloper", "Probe Cannon", "End Times", "Wormholes", "Time Rewind"]
	var kinds := ["BALL", "LAUNCHER", "BACKGROUND", "MOD", "MOD"]
	var gap := (1080.0 - CARD_SIZE.x * 5.0) / 6.0
	for i in range(5):
		var card := _card(names[i], kinds[i], makers[i].call())
		card.position = Vector2(gap + i * (CARD_SIZE.x + gap), 1200.0)
		card.pivot_offset = CARD_SIZE * 0.5
		card.scale = Vector2(0.0, 1.0)
		add_child(card)
		_cards.append(card)

	_continue = NeonUI.button("CONTINUE", true)
	_continue.position = Vector2(270.0, 1560.0)
	_continue.size = Vector2(540.0, NeonUI.BUTTON_HEIGHT)
	_continue.modulate.a = 0.0
	_continue.disabled = true
	_continue.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	add_child(_continue)

## Characters placed along the spiral at even arc-length steps.
func _layout_spiral() -> void:
	var theta := 0.0
	for ch in TEXT:
		var r := SPIRAL_A + SPIRAL_B * theta
		var pos := SPIRAL_CENTER + Vector2(cos(theta), sin(theta)) * r
		_glyphs.append({"pos": pos, "angle": theta + PI * 0.5, "char": ch})
		# d(arc)/d(theta) ~= r, so step theta by CHAR_STEP / r.
		theta += CHAR_STEP / maxf(r, 1.0)

func _gui_input(event: InputEvent) -> void:
	# A click before the end skips straight to it.
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and _t < DONE_AT:
		_t = DONE_AT
		accept_event()

func _process(delta: float) -> void:
	_t += delta
	for i in range(_cards.size()):
		var start := CARDS_START + i * CARD_STAGGER
		_cards[i].scale.x = ease(clampf((_t - start) / CARD_FLIP, 0.0, 1.0), -2.0)
	_title.modulate.a = clampf((_t - CARDS_START + 0.3) / 0.4, 0.0, 1.0)
	if _t >= DONE_AT:
		_continue.disabled = false
		_continue.modulate.a = clampf((_t - DONE_AT) / 0.4, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.05, 0.85 * clampf(_t / DIM_END, 0.0, 1.0)), true)
	var progress := clampf((_t - TEXT_START) / (TEXT_END - TEXT_START), 0.0, 1.0)
	var shown := int(progress * _glyphs.size())
	var font := ThemeDB.fallback_font
	# The spiral's faint guide line, then the written characters, the newest
	# one brightest.
	if shown > 1:
		var guide := PackedVector2Array()
		for i in range(shown):
			guide.append(_glyphs[i].pos)
		draw_polyline(guide, Color(NOMAI_BLUE, 0.12), 26.0, true)
	for i in range(shown):
		var g: Dictionary = _glyphs[i]
		var fresh := clampf(1.0 - (shown - i) / 12.0, 0.0, 1.0)
		var col := NOMAI_BLUE.lerp(Color.WHITE, fresh)
		col.a = 0.75 + 0.25 * fresh
		draw_set_transform(g.pos, g.angle)
		draw_char(font, Vector2(-SPIRAL_FONT * 0.3, SPIRAL_FONT * 0.35), g.char, SPIRAL_FONT, col)
	draw_set_transform(Vector2.ZERO, 0.0)
	if shown > 0 and shown < _glyphs.size():
		draw_circle(_glyphs[shown - 1].pos, 10.0 + 4.0 * sin(_t * 20.0), Color(1, 1, 1, 0.6))


# ------------------------------------------------------------------- cards

func _card(title: String, kind: String, preview: Control) -> Control:
	var card := PanelContainer.new()
	card.size = CARD_SIZE
	card.custom_minimum_size = CARD_SIZE
	var style := NeonUI.panel_style()
	style.border_color = NOMAI_BLUE
	style.shadow_color = Color(NOMAI_BLUE, 0.35)
	style.set_content_margin_all(12.0)
	card.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	col.add_child(NeonUI.label(kind, 16, NeonUI.TEXT_DIM))
	preview.custom_minimum_size = Vector2(CARD_SIZE.x - 24.0, 160.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.clip_contents = true
	col.add_child(preview)
	var name_label := NeonUI.label(title, 22, NeonUI.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_label)
	return card

## A Control that redraws every frame through `fn(control, rect, t)`.
func _live(fn: Callable) -> Control:
	var c := Control.new()
	var clock := [0.0]
	c.draw.connect(func() -> void: fn.call(c, Rect2(Vector2.ZERO, c.size), clock[0]))
	var ticker := Timer.new()
	ticker.wait_time = 1.0 / 60.0
	ticker.autostart = true
	ticker.timeout.connect(func() -> void:
		clock[0] += ticker.wait_time
		c.queue_redraw())
	c.add_child(ticker)
	return c

func _interloper_card() -> Control:
	var look: BallLook = preload("res://scripts/skins/balls/interloper.gd").new()
	return _live(func(c: Control, r: Rect2, t: float) -> void:
		PreviewDraw.board(c, r)
		var p := PreviewDraw.phase(t, 2.2)
		var pos := PreviewDraw.at(r, 0.15 + p * 0.7, 0.75 - p * 0.45)
		for k in range(8):
			var f := k / 8.0
			var tail := pos - Vector2(0.7, -0.45).normalized() * f * 60.0
			c.draw_circle(tail, 14.0 * (1.0 - f), Color(look.trail_color, 0.5 * (1.0 - f)))
		look.draw(c, pos, 16.0, p * 12.0, t))

func _cannon_card() -> Control:
	return _live(func(c: Control, r: Rect2, t: float) -> void:
		PreviewDraw.board(c, r)
		var flash := maxf(0.0, 1.0 - fposmod(t, 1.2) / 0.25)
		Shooter.draw_probe_cannon(c, PreviewDraw.at(r, 0.5, 0.85), Vector2.UP.rotated(-0.3), 0.8, flash))

## A card-sized sketch of the cycle -- the real background's stars shrink
## below a pixel at card scale.
func _end_times_card() -> Control:
	var stars: Array[Vector2] = []
	var deaths: Array[float] = []
	for i in range(18):
		stars.append(Vector2(randf(), randf()))
		deaths.append(randf_range(0.05, 0.7))
	return _live(func(c: Control, r: Rect2, t: float) -> void:
		c.draw_rect(r, Color("#06080c"), true)
		var p := PreviewDraw.phase(t, 4.0)
		for i in range(stars.size()):
			var pos := r.position + stars[i] * r.size
			if p < deaths[i]:
				c.draw_circle(pos, 1.8, Color(1, 1, 1, 0.8))
			elif p < deaths[i] + 0.08 and i % 3 == 0:
				var f := (p - deaths[i]) / 0.08
				c.draw_arc(pos, 3.0 + f * 22.0, 0.0, TAU, 20, Color(1.0, 0.82, 0.48, 1.0 - f), 2.0, true)
		if p > 0.8:
			var b := (p - 0.8) / 0.2
			c.draw_circle(r.get_center(), r.size.length() * 0.5 * b, Color(1.0, 0.9, 0.7, (1.0 - b) * 0.6)))

func _wormholes_card() -> Control:
	var icon := ModPreviewIcon.new(Cfg.Wormholes.new())
	icon.playing = true
	return icon

func _rewind_card() -> Control:
	var icon := ModPreviewIcon.new(Cfg.TimeRewind.new())
	icon.playing = true
	return icon
