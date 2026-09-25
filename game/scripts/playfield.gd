class_name Playfield
extends RefCounted
## The board's moving parts, bundled so mods' field hooks (added with the
## Outer Wilds mods) and the ? panel's live preview can share them. Game
## builds the real one; ModLivePreview builds its own, so a mod can't tell a
## preview board from a real run.
##
## Also home to the wall builder both of them use, so the preview's walls
## are the real walls, not a copy.

var rules: GameRules
var grid: GridManager
var effects_root: Node2D

## Solid rectangles rather than WorldBoundaryShape2D: a fast ball that clips a
## boundary line can end up on the wrong side of it, a thick box it cannot.
## Side walls sit at rules.play_left / play_right, the ceiling at grid_top.
static func build_walls(root: Node2D, rules: GameRules, view_width: float) -> void:
	for child in root.get_children():
		child.queue_free()

	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("wall")
	root.add_child(body)

	var span := rules.floor_y - rules.grid_top
	var mid_y := (rules.grid_top + rules.floor_y) * 0.5
	var thickness := 400.0

	_add_wall(body, Vector2(thickness, span + thickness * 2.0), Vector2(rules.play_left - thickness * 0.5, mid_y))
	_add_wall(body, Vector2(thickness, span + thickness * 2.0), Vector2(rules.play_right + thickness * 0.5, mid_y))
	_add_wall(body, Vector2(view_width + thickness * 2.0, thickness),
		Vector2(view_width * 0.5, rules.grid_top - thickness * 0.5))

static func _add_wall(body: StaticBody2D, size: Vector2, pos: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = pos
	body.add_child(shape)
