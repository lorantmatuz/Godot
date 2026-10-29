extends "res://tests/_test_case.gd"

# Camera zoom, edge scrolling, clamping and focus.


func run() -> void:
	print("camera")
	var rule := CameraController.new()

	check(
		"the mouse in a margin scrolls toward that edge",
		rule.mouse_edge_direction(Vector2(2.0, 2.0), Vector2(1024.0, 768.0)) == Vector2(-1.0, -1.0)
		and rule.mouse_edge_direction(Vector2(1022.0, 766.0), Vector2(1024.0, 768.0)) == Vector2.ONE
	)
	check(
		"the mouse in the middle does not scroll",
		rule.mouse_edge_direction(Vector2(512.0, 384.0), Vector2(1024.0, 768.0)) == Vector2.ZERO
	)
	rule.free()

	var scene: PackedScene = load("res://scenes/levels/main.tscn")
	var main = scene.instantiate()
	# The headless virtual mouse sits at (0,0), which the margin rule would read as
	# "hold top-left", so the movement checks drive the camera with keys only.
	(main.get_node("Camera2D") as CameraController).edge_margin = 0.0
	root.add_child(main)
	await process_frame

	var camera: CameraController = main.get_node("Camera2D")
	var max_position := _camera_max_position(camera)
	var world_size := MAP_SIZE * TILE_SIZE

	check("camera starts zoomed to whole pixels at 2x", camera.zoom == Vector2(2.0, 2.0), str(camera.zoom))
	check(
		"camera starts at the map center",
		camera.position.is_equal_approx(Vector2.ONE * world_size / 2.0),
		str(camera.position)
	)
	check(
		"camera is clamped to the map edges",
		camera.limit_left == 0
		and camera.limit_top == 0
		and camera.limit_right == world_size
		and camera.limit_bottom == world_size,
		"limits=%d,%d,%d,%d" % [
			camera.limit_left, camera.limit_top,
			camera.limit_right, camera.limit_bottom
		]
	)

	var half_view := camera.get_viewport_rect().size / camera.zoom / 2.0
	camera.focus_on(Vector2(-500.0, -500.0))
	check(
		"focus_on clamps to the top-left limit",
		camera.position.is_equal_approx(half_view),
		str(camera.position)
	)

	camera.position = max_position + Vector2(600.0, 600.0)
	await process_frame
	check(
		"camera position is clamped to the map limit",
		camera.position.is_equal_approx(max_position),
		str(camera.position)
	)

	Input.action_press("camera_right")
	await create_timer(0.2).timeout
	Input.action_release("camera_right")
	check(
		"holding into the border does not overshoot",
		camera.position.is_equal_approx(max_position),
		str(camera.position)
	)

	Input.action_press("camera_left")
	await create_timer(0.2).timeout
	Input.action_release("camera_left")
	check(
		"reversing from the border moves immediately",
		camera.position.x < max_position.x - 1.0,
		str(camera.position)
	)

	main.queue_free()
	await process_frame
	finish()


func _camera_max_position(camera: Camera2D) -> Vector2:
	var half_size := camera.get_viewport_rect().size / camera.zoom / 2.0
	return Vector2(
		camera.limit_right - half_size.x,
		camera.limit_bottom - half_size.y
	)
