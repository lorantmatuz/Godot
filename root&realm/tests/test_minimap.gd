extends "res://tests/_test_case.gd"

# The minimap: image pixels, view rect, click-to-move and refresh.


func run() -> void:
	print("minimap")
	var scene: PackedScene = load("res://scenes/levels/main.tscn")
	var main = scene.instantiate()
	# Mute edge scroll before the first frame: the headless virtual mouse sits at
	# (0,0) and would drift the camera this file checks.
	(main.get_node("Camera2D") as CameraController).edge_margin = 0.0
	root.add_child(main)
	await process_frame

	var camera: CameraController = main.get_node("Camera2D")
	var minimap: Minimap = main.minimap
	var renderer = main.world_renderer
	var world: WorldGrid = renderer.world

	check(
		"the minimap sits on a screen-space layer and sees the world",
		minimap.get_parent() is CanvasLayer and minimap.world == world
	)
	check(
		"the minimap is sized from the map in whole tiles",
		minimap.get("_image").get_size() == world.size
		and minimap.size == Vector2(world.size * Minimap.PIXELS_PER_TILE),
		"%s px, %s image" % [minimap.size, minimap.get("_image").get_size()]
	)

	var image: Image = minimap.get("_image")
	var pixels_ok := true
	var forest_pixels := 0

	for y in range(world.size.y):
		for x in range(world.size.x):
			var expected: Color = Minimap.TERRAIN_COLORS[world.get_terrain(x, y)]

			for id in world.objects_by_tile.get(Vector2i(x, y), []):
				if world.objects_by_id[id]["type"] == "tree":
					expected = Minimap.TREE_COLOR

			if expected == Minimap.TREE_COLOR:
				forest_pixels += 1
			if image.get_pixel(x, y) != expected:
				pixels_ok = false

	check(
		"the minimap draws the terrain and the forest",
		pixels_ok and forest_pixels > 0,
		"%d forest pixels" % forest_pixels
	)

	camera.focus_on(Vector2.ONE * MAP_SIZE * TILE_SIZE / 2.0)
	await process_frame
	check(
		"the view rect is centred when the camera is",
		minimap.view_rect().get_center().is_equal_approx(minimap.size / 2.0),
		str(minimap.view_rect())
	)

	var wide := minimap.view_rect().size
	camera.change_zoom(1.0)
	check(
		"zooming in shrinks the view rect",
		minimap.view_rect().size.is_equal_approx(wide * 2.0 / 3.0),
		"%s -> %s" % [wide, minimap.view_rect().size]
	)

	camera.focus_on(Vector2.ZERO)
	check(
		"the view rect stays inside the minimap at a map corner",
		Rect2(Vector2.ZERO, minimap.size).encloses(minimap.view_rect()),
		str(minimap.view_rect())
	)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(32.0, 32.0)
	minimap._gui_input(click)
	check(
		"clicking the minimap centres the camera on that tile",
		camera.position.is_equal_approx(Vector2(16.5, 16.5) * TILE_SIZE),
		str(camera.position)
	)

	await process_frame
	check(
		"the minimap follows the camera every frame",
		minimap.get("_view").is_equal_approx(minimap.view_rect())
	)

	var tree_id := -1

	for obj in world.objects:
		if obj["type"] == "tree":
			tree_id = obj["id"]
			break

	var tree: Dictionary = world.objects_by_id[tree_id]
	var tree_tile := Vector2i(tree["x"], tree["y"])
	check(
		"a tree tile is drawn as forest",
		image.get_pixel(tree_tile.x, tree_tile.y) == Minimap.TREE_COLOR
	)

	world.remove_object(tree_id)
	renderer.remove_object(tree_id)
	minimap.refresh()
	check(
		"felling a tree clears its minimap pixel",
		minimap.get("_image").get_pixel(tree_tile.x, tree_tile.y)
		== Minimap.TERRAIN_COLORS[world.get_terrain(tree_tile.x, tree_tile.y)]
	)

	main.queue_free()
	await process_frame
	finish()
