extends CharacterBody2D

const SPEED := 420.0

var attached := true

func _ready() -> void:
	reset()

func reset() -> void:
	velocity = Vector2.ZERO
	attached = true

func _physics_process(delta: float) -> void:
	if attached:                       # glued until you launch
		var paddle := get_tree().get_first_node_in_group("paddle")
		if paddle:
			position = paddle.position + Vector2(0, -30)
		if Input.is_action_just_pressed("launch"):
			attached = false
			velocity = Vector2.UP.rotated(randf_range(-0.4, 0.4)) * SPEED
		return

	var collision := move_and_collide(velocity * delta)
	if collision == null:
		return
	var collider := collision.get_collider()
	if collider.is_in_group("brick"):
		collider.take_hit()            # score happens via brick's signal
	if collider.is_in_group("paddle"):
		# steer: where you hit the paddle decides the angle
		var offset := clampf((position.x - collider.global_position.x) / 55.0, -1.0, 1.0)
		velocity = Vector2.UP.rotated(offset * deg_to_rad(60.0)) * SPEED
	else:
		velocity = velocity.bounce(collision.get_normal())
		if absf(velocity.y) < 30.0:    # never let it drift fully horizontal
			velocity.y = 60.0 * (1.0 if velocity.y >= 0.0 else -1.0)
