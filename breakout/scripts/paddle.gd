extends CharacterBody2D

const SPEED := 600.0

# The capsule is rotated 90 degrees, so its height is the on-screen width.
@onready var half_width: float = ($CollisionShape2D.shape as CapsuleShape2D).height / 2.0

# Actual movement this frame (read by the ball on impact); 0 when held against a wall.
var motion_velocity := 0.0

func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	var limit := get_viewport_rect().size.x - half_width
	var start_x := position.x
	position.x = clampf(position.x + dir * SPEED * delta, half_width, limit)
	if delta > 0.0:
		motion_velocity = (position.x - start_x) / delta
