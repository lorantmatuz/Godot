class_name CameraController
extends Camera2D

## Free camera over the generated map. The kit is 32 px per tile, so the zoom
## levels are whole numbers (crisp nearest-neighbour pixels) and start at 2 to
## match the framing the 64 px world used to have.

@export var move_speed := 250.0
@export var min_zoom := 1.0
@export var max_zoom := 4.0
@export var start_zoom := 2.0

@export var edge_margin: float = 10.0

var _zoom := 2.0
var _panning := false


func _ready() -> void:
	_zoom = clampf(start_zoom, min_zoom, max_zoom)
	zoom = Vector2.ONE * _zoom


func _process(delta: float) -> void:
	var direction := Input.get_vector(
		"camera_left",
		"camera_right",
		"camera_up",
		"camera_down"
	)

	direction += mouse_edge_direction(
		get_viewport().get_mouse_position(),
		get_viewport_rect().size
	)

	if direction.length() > 1.0:
		direction = direction.normalized()

	position += direction * move_speed * delta
	_clamp_to_limits()


func mouse_edge_direction(mouse_pos: Vector2, viewport_size: Vector2) -> Vector2:
	## Scroll toward whichever screen margin the mouse is in. Takes the position
	## and size as arguments so the rule can be tested without a real pointer.
	var direction := Vector2.ZERO

	if mouse_pos.x < edge_margin:
		direction.x -= 1.0
	elif mouse_pos.x > viewport_size.x - edge_margin:
		direction.x += 1.0

	if mouse_pos.y < edge_margin:
		direction.y -= 1.0
	elif mouse_pos.y > viewport_size.y - edge_margin:
		direction.y += 1.0

	return direction


func _unhandled_input(event: InputEvent) -> void:
	# Middle-drag pans because placement takes the left button.
	var button := event as InputEventMouseButton

	if button != null and button.button_index == MOUSE_BUTTON_MIDDLE:
		_panning = button.pressed
		return

	var motion := event as InputEventMouseMotion

	if motion != null and _panning:
		pan_by(motion.relative)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("zoom_in"):
		change_zoom(1.0)
	elif event.is_action_pressed("zoom_out"):
		change_zoom(-1.0)


func pan_by(screen_delta: Vector2) -> void:
	## Drags the map with the pointer, so the camera moves the other way; the
	## delta is in screen pixels, which zoom turns into world pixels.
	position -= screen_delta / zoom
	_clamp_to_limits()


func change_zoom(amount: float) -> void:
	var new_zoom := clampf(_zoom + amount, min_zoom, max_zoom)

	if is_equal_approx(new_zoom, _zoom):
		return

	_zoom = new_zoom
	zoom = Vector2.ONE * _zoom
	_clamp_to_limits()


func focus_on(world_point: Vector2) -> void:
	## Centres the camera on a world point, kept inside the map limits.
	position = world_point
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
