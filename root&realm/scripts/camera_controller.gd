extends Camera2D

@export var move_speed := 500.0
@export var zoom_step := 0.1
@export var min_zoom := 0.5
@export var max_zoom := 2.0


func _process(delta: float) -> void:
	var direction := Input.get_vector(
		"camera_left",
		"camera_right",
		"camera_up",
		"camera_down"
	)

	position += direction * move_speed * delta
	_clamp_to_limits()

	if Input.is_action_pressed("zoom_in"):
		change_zoom(zoom_step * delta * 3.0)

	if Input.is_action_pressed("zoom_out"):
		change_zoom(-zoom_step * delta * 3.0)


func change_zoom(amount: float) -> void:
	var new_zoom: float = clampf(
		zoom.x + amount,
		min_zoom,
		max_zoom
	)
	zoom = Vector2.ONE * new_zoom
	_clamp_to_limits()


func _clamp_to_limits() -> void:
	# Camera2D limits only clamp the rendered view, not this node's position.
	# Without this, holding a direction at the border accumulates an invisible
	# offset that has to be unwound before the camera visibly moves back.
	var half_size := get_viewport_rect().size / zoom / 2.0

	position.x = _clamped_axis(position.x, limit_left, limit_right, half_size.x)
	position.y = _clamped_axis(position.y, limit_top, limit_bottom, half_size.y)


func _clamped_axis(value: float, lower: int, upper: int, half_extent: float) -> float:
	var min_value := lower + half_extent
	var max_value := upper - half_extent

	if min_value > max_value:
		return (lower + upper) / 2.0

	return clampf(value, min_value, max_value)
