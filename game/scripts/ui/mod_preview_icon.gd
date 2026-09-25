class_name ModPreviewIcon
extends Control
## A mod's tile icon: GameMod.draw_preview frozen at t = 0, animating while
## `playing` (the owning tile turns it on while hovered). Locked mods draw a
## silhouette instead, so their sketch doesn't give them away.

var mod: GameMod
var locked: bool = false
var playing: bool = false:
	set(value):
		playing = value
		if not value:
			_t = 0.0
		set_process(value)
		queue_redraw()

var _t: float = 0.0

func _init(m: GameMod = null, is_locked: bool = false) -> void:
	mod = m
	locked = is_locked
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if locked:
		PreviewDraw.board(self, r)
		PreviewDraw.text(self, r.get_center(), "?", int(r.size.y * 0.45), PreviewDraw.FRAME)
	elif mod == null:
		PreviewDraw.board(self, r)
		PreviewDraw.text(self, r.get_center(), "-", int(r.size.y * 0.4), PreviewDraw.FRAME)
	else:
		mod.draw_preview(self, r, _t)
