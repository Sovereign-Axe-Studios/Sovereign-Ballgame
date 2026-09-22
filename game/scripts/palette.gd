class_name Palette
extends RefCounted
## Shared colours. Block health follows ROYGBIV across 0..100 as specced.

const BACKGROUND := Color("#11151c")
const WALL := Color("#2b3442")
const FLOOR_LINE := Color("#3c4759")
const BALL := Color("#eceff1")
const PICKUP := Color("#7cf7c4")
const TEXT := Color("#e6ebf2")
const TEXT_DIM := Color("#8b97a8")

## Red at low health through violet at `max_value`, clamped at both ends.
const ROYGBIV := [
	Color("#e53935"), # red
	Color("#fb8c00"), # orange
	Color("#fdd835"), # yellow
	Color("#43a047"), # green
	Color("#1e88e5"), # blue
	Color("#3949ab"), # indigo
	Color("#8e24aa"), # violet
]

static func health_color(value: int, max_value: int = 100) -> Color:
	var t := clampf(float(value) / float(maxi(1, max_value)), 0.0, 1.0)
	var scaled := t * float(ROYGBIV.size() - 1)
	var i := int(floor(scaled))
	if i >= ROYGBIV.size() - 1:
		return ROYGBIV[ROYGBIV.size() - 1]
	return ROYGBIV[i].lerp(ROYGBIV[i + 1], scaled - float(i))

## Dark or light label text, whichever reads against the block colour.
static func label_color(on: Color) -> Color:
	var luma := 0.299 * on.r + 0.587 * on.g + 0.114 * on.b
	return Color("#10141a") if luma > 0.55 else Color("#f5f7fa")
