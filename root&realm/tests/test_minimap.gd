extends "res://tests/_test_case.gd"

# The minimap: image pixels, frame, view rect, click-to-move and refresh.


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
		"the minimap is the map in whole tiles plus the frame",
		minimap.get("_image").get_size() == world.size
		and minimap.map_rect().position == Vector2.ONE * Minimap.BORDER
		and minimap.map_rect().size == Vector2(world.size * Minimap.PIXELS_PER_TILE)
		and minimap.size == minimap.map_rect().end + Vector2.ONE * Minimap.BORDER,
		"%s px, %s image" % [minimap.size, minimap.get("_image").get_size()]
	)

	var image: Image = minimap.get("_image")
	var expected := Image.create(world.size.x, world.size.y, false, Image.FORMAT_RGBA8)
	var trees := 0
	var small := 0
	var buildings := 0

	for y in range(world.size.y):
		for x in range(world.size.x):
			expected.set_pixel(x, y, Minimap.TERRAIN_COLORS[world.get_terrain(x, y)])

	# Mirror refresh(): a building paints its footprint, a tree replaces its
	# tile, anything smaller tints it.
	for obj in world.objects:
		if obj["type"] == "building":
			minimap.paint_building(expected, obj)
			buildings += 1
			continue

		var color: Color = minimap.object_color(obj)

		if obj["type"] == "tree":
			expected.set_pixel(obj["x"], obj["y"], color)
			trees += 1
		else:
			small += 1
			expected.set_pixel(
				obj["x"],
				obj["y"],
				expected.get_pixel(obj["x"], obj["y"]).lerp(color, Minimap.SMALL_OBJECT_TINT)
			)

	check(
		"the minimap draws the terrain, the trees, the small objects and the camp",
		image.get_data() == expected.get_data() and trees > 0 and small > 0 and buildings > 0,
		"%d trees, %d small objects, %d buildings" % [trees, small, buildings]
	)

	var tufts: Array = world.objects.filter(func(o): return o["type"] == "tuft")
	var tuft: Dictionary = tufts[0]
	var tuft_pixel: Color = image.get_pixel(tuft["x"], tuft["y"])
	var soil: Color = Minimap.TERRAIN_COLORS[WorldGrid.Terrain.SOIL]

	check(
		"tufts read as green on tilled soil",
		world.get_terrain(tuft["x"], tuft["y"]) == WorldGrid.Terrain.SOIL
		and tuft_pixel != soil
		and tuft_pixel.g > soil.g,
		tuft_pixel.to_html(false)
	)
	check(
		"every kit prop has a map colour",
		WorldRenderer.PROP_TEXTURES.keys().all(
			func(name): return Minimap.PROP_COLORS.has(name)
		)
	)

	var grass: Image = WorldRenderer.FILL_TILESET.get_source(0).texture.get_image()
	var dirt: Image = WorldRenderer.SOIL_TILESET.get_source(0).texture.get_image()
	var water: Image = WorldRenderer.WATER_TILESET.get_source(0).texture.get_image()
	# (3, 3) is the atlases' full-dirt / full-water tile.
	var solid := Rect2i(Vector2i(3, 3) * TILE_SIZE, Vector2i(TILE_SIZE, TILE_SIZE))

	check(
		"the minimap ground matches the art",
		_close(Minimap.TERRAIN_COLORS[WorldGrid.Terrain.GRASS], _average(grass, Rect2i(
			Vector2i.ZERO, grass.get_size()
		)))
		and _close(Minimap.TERRAIN_COLORS[WorldGrid.Terrain.SOIL], _average(dirt, solid))
		and _close(Minimap.TERRAIN_COLORS[WorldGrid.Terrain.WATER], _average(water, solid))
	)

	var cherry: Color = minimap.tree_color(TreeEntity.TreeStage.MATURE, "cherry")
	var pine: Color = minimap.tree_color(TreeEntity.TreeStage.MATURE, "pine")
	check(
		"a blooming cherry reads pink and a pine green",
		cherry.r > cherry.g and pine.g > pine.r,
		"%s vs %s" % [cherry.to_html(false), pine.to_html(false)]
	)

	var species_colors := {}

	for species in WorldGenerator.MATURE_SPECIES:
		species_colors[minimap.tree_color(TreeEntity.TreeStage.MATURE, species)] = true

	check(
		"every tree species gets its own dot",
		species_colors.size() == WorldGenerator.MATURE_SPECIES.size(),
		str(species_colors.size())
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
		"the view rect stays inside the map at a map corner",
		minimap.map_rect().encloses(minimap.view_rect()),
		str(minimap.view_rect())
	)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = minimap.map_rect().position + Vector2(32.0, 32.0)
	minimap._gui_input(click)
	check(
		"clicking the minimap centres the camera on that tile",
		camera.position.is_equal_approx(Vector2(16.5, 16.5) * TILE_SIZE),
		str(camera.position)
	)

	var before := camera.position
	click.position = Vector2.ONE
	minimap._gui_input(click)
	check(
		"clicking the frame does not move the camera",
		camera.position.is_equal_approx(before),
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
		"a tree tile is drawn as its own tree",
		image.get_pixel(tree_tile.x, tree_tile.y)
		== minimap.tree_color(tree["stage"], tree.get("species", ""))
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


func _average(image: Image, rect: Rect2i) -> Color:
	var sum := Color(0, 0, 0, 0)

	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			sum += image.get_pixel(x, y)

	return sum / float(rect.size.x * rect.size.y)


func _close(a: Color, b: Color, tolerance := 0.06) -> bool:
	return (
		absf(a.r - b.r) <= tolerance
		and absf(a.g - b.g) <= tolerance
		and absf(a.b - b.b) <= tolerance
	)
