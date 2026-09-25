class_name FallingBall
extends Node2D
## The +1-ball pickup's response: a purely cosmetic ball that drops from the
## pickup's spot to the floor and reports back once it lands. Never
## collides, never damages anything, and is not one of the real balls Game
## tracks for the round -- `Game._on_pickup_collected` spawns one of these
## instead of incrementing `pending_balls` directly, so the count only ticks
## up once the ball is actually seen landing, not the instant it's collected.

signal landed(ball: FallingBall)

const GRAVITY := 1400.0
const INITIAL_SPEED := 60.0

## Set by Game._end_round when the round resolves before this lands, so
## the landing doesn't count the same ball twice.
var credited: bool = false
var _radius: float = 17.0
var _floor_y: float = 0.0
var _speed: float = -INITIAL_SPEED

func setup(radius: float, floor_y: float) -> void:
	_radius = radius
	_floor_y = floor_y
	queue_redraw()

func _process(delta: float) -> void:
	_speed += GRAVITY * delta
	position.y += _speed * delta
	if position.y >= _floor_y:
		position.y = _floor_y
		landed.emit(self)
		queue_free()

func _draw() -> void:
	var skin := Skins.ball()
	draw_circle(Vector2.ZERO, _radius, skin.color)
	draw_circle(Vector2(-_radius * 0.3, -_radius * 0.3), _radius * 0.3, skin.highlight)
