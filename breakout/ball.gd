extends CharacterBody2D

const SPEED := 420.0
const MIN_COMPONENT := 40.0
const PADDLE_MOTION_BIAS := 0.3   # how much paddle motion biases a top-face hit
const PADDLE_IMPACT := 0.5    # momentum transfer on a side hit
const TOP_FACE := -0.5        # normal.y below this means the ball hit the top

var attached := true

func _ready() -> void:
	reset()

func reset() -> void:
	velocity = Vector2.ZERO
	attached = true
	var paddle := get_tree().get_first_node_in_group("paddle")
	if paddle:
		position = paddle.position + Vector2(0, -40)

func _physics_process(delta: float) -> void:
	if attached:                       # glued until you launch
		var paddle := get_tree().get_first_node_in_group("paddle")
		if paddle:
			position = paddle.position + Vector2(0, -40)
		if Input.is_action_just_pressed("launch"):
			attached = false
			velocity = Vector2.UP.rotated(randf_range(-0.4, 0.4)) * SPEED
		return

	var collision := move_and_collide(velocity * delta)
	if collision == null:
		return
	var collider := collision.get_collider()
	var normal := collision.get_normal()
	if collider.is_in_group("brick"):
		collider.take_hit()            # score happens via brick's signal

	if collider.is_in_group("paddle") and normal.y < TOP_FACE:
		# top face: aim with the paddle, biased a little by its sideways motion
		var offset := clampf((global_position.x - collider.global_position.x) / 55.0, -1.0, 1.0)
		var steer := Vector2.UP.rotated(offset * deg_to_rad(60.0))
		steer.x += (collider.motion_velocity / SPEED) * PADDLE_MOTION_BIAS
		velocity = steer.normalized() * SPEED
	else:
		# walls and bricks just reflect; a moving paddle side imparts momentum
		var surface_velocity := Vector2.ZERO
		if collider.is_in_group("paddle"):
			surface_velocity.x = collider.motion_velocity * PADDLE_IMPACT
		velocity = (velocity - surface_velocity).bounce(normal) + surface_velocity
	velocity = _safe_direction(velocity)

func _safe_direction(v: Vector2) -> Vector2:
	# Keep a minimum speed on both axes so the ball cannot loop forever
	# horizontally between the walls or vertically in a cleared column.
	if v == Vector2.ZERO:
		return v
	v = v.normalized() * SPEED
	v.x = _min_component(v.x)
	v.y = _min_component(v.y)
	return v.normalized() * SPEED

func _min_component(value: float) -> float:
	if absf(value) >= MIN_COMPONENT:
		return value
	var dir := signf(value)
	if dir == 0.0:
		dir = 1.0 if randf() < 0.5 else -1.0
	return MIN_COMPONENT * dir
