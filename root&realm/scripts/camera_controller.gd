
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
