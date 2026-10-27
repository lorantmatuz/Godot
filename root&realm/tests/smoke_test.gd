extends SceneTree

# Headless smoke test: godot --headless --path "root&realm" --script res://tests/smoke_test.gd

const WORLD_SEED := 12345
const TILE_SIZE := 64

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_test_generation()
	_test_placement()
	await _test_camera_bounds()
	await _test_main_scene()
	print("smoke test: ", "FAIL (%d)" % failures if failures > 0 else "PASS")
	quit(1 if failures > 0 else 0)


func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		failures += 1
	print(("  ok   " if ok else "  FAIL ") + label + ("  [" + detail + "]" if detail != "" else ""))


func _test_generation() -> void:
	print("world generation")
	var first := WorldGenerator.new().generate_world(WORLD_SEED)
	var second := WorldGenerator.new().generate_world(WORLD_SEED)
	var other := WorldGenerator.new().generate_world(WORLD_SEED + 1)

	_check("same seed reproduces the terrain", first.terrain == second.terrain)
	_check("same seed reproduces the objects", first.objects == second.objects)
	_check("a different seed changes the world", first.terrain != other.terrain)


func _test_placement() -> void:
	print("world layout")
	var world := WorldGenerator.new().generate_world(WORLD_SEED)
	var center := Vector2(world.size) / 2.0

	var counts := {}
	var clearing_grass := true
	var clearing_empty := true
	var objects_in_water := 0
	var trees_on_land := true
	var stones_on_rock := true
	var trees_near_start := 0
	var stones_near_start := 0
	var stages := {}

	for y in range(world.size.y):
		for x in range(world.size.x):
			var terrain: WorldGrid.Terrain = world.get_terrain(x, y)
			counts[terrain] = counts.get(terrain, 0) + 1

			if Vector2(x, y).distance_to(center) <= WorldGenerator.CLEARING_RADIUS:
				if terrain != WorldGrid.Terrain.GRASS:
					clearing_grass = false

	for obj in world.objects:
		var tile := Vector2(obj["x"], obj["y"])
		var terrain: WorldGrid.Terrain = world.get_terrain(obj["x"], obj["y"])

		if terrain == WorldGrid.Terrain.WATER:
			objects_in_water += 1

		if tile.distance_to(center) <= WorldGenerator.OBJECT_CLEARING_RADIUS:
			clearing_empty = false

		if obj["type"] == "tree":
			stages[obj["stage"]] = true

			if terrain != WorldGrid.Terrain.GRASS and terrain != WorldGrid.Terrain.FOREST_FLOOR:
				trees_on_land = false

			if tile.distance_to(center) <= WorldGenerator.START_RESOURCE_RADIUS:
				trees_near_start += 1

		elif obj["type"] == "stone":
			if terrain != WorldGrid.Terrain.ROCKY:
				stones_on_rock = false

			if tile.distance_to(center) <= WorldGenerator.START_RESOURCE_RADIUS:
				stones_near_start += 1

	_check("terrain is 64x64", world.size == Vector2i(64, 64), str(world.size))
	_check(
		"water, grass, forest, and rock are all present",
		counts.has(WorldGrid.Terrain.WATER)
		and counts.has(WorldGrid.Terrain.GRASS)
		and counts.has(WorldGrid.Terrain.FOREST_FLOOR)
		and counts.has(WorldGrid.Terrain.ROCKY),
		str(counts)
	)
	_check("the starting clearing is grass", clearing_grass)
	_check("the starting clearing is empty", clearing_empty)
	_check("no objects are placed in water", objects_in_water == 0, str(objects_in_water))
	_check("trees grow on grass or forest floor", trees_on_land)
	_check("stone sits on rocky ground", stones_on_rock)
	_check("a grove is reachable from the start", trees_near_start >= 5, str(trees_near_start))
	_check("an outcrop is reachable from the start", stones_near_start >= 4, str(stones_near_start))
	_check("trees are spread across growth stages", stages.size() >= 2, str(stages.keys()))


func _test_camera_bounds() -> void:
	print("camera bounds")
	var scene: PackedScene = load("res://scenes/levels/main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame

	var camera: Camera2D = main.get_node("Camera2D")
	var max_position := _camera_max_position(camera)

	camera.position = max_position + Vector2(600.0, 600.0)
	await process_frame
	_check(
		"camera position is clamped to the map limit",
		camera.position.is_equal_approx(max_position),
		str(camera.position)
	)

	Input.action_press("camera_right")
	await create_timer(0.2).timeout
	Input.action_release("camera_right")
	_check(
		"holding into the border does not overshoot",
		camera.position.is_equal_approx(max_position),
		str(camera.position)
	)

	Input.action_press("camera_left")
	await create_timer(0.2).timeout
	Input.action_release("camera_left")
	_check(
		"reversing from the border moves immediately",
		camera.position.x < max_position.x - 1.0,
		str(camera.position)
	)

	main.queue_free()
	await process_frame


func _camera_max_position(camera: Camera2D) -> Vector2:
	var half_size := camera.get_viewport_rect().size / camera.zoom / 2.0
	return Vector2(
		camera.limit_right - half_size.x,
		camera.limit_bottom - half_size.y
	)


func _test_main_scene() -> void:
	print("main scene")
	var scene: PackedScene = load("res://scenes/levels/main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame

	var camera: Camera2D = main.get_node("Camera2D")
	var world_size := WorldGenerator.MAP_SIZE * TILE_SIZE

	_check(
		"camera starts at the map center",
		camera.position.is_equal_approx(Vector2.ONE * world_size / 2.0),
		str(camera.position)
	)
	_check(
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

	var renderer = main.world_renderer
	var world: WorldGrid = renderer.world

	_check("ground is a tilemap", renderer.ground is TileMapLayer)
	_check("ground has a tileset", renderer.ground.tile_set != null)

	var ground_source: TileSetAtlasSource = null
	if renderer.ground.tile_set != null:
		ground_source = renderer.ground.tile_set.get_source(0) as TileSetAtlasSource

	_check(
		"ground atlas is generated",
		ground_source != null and ground_source.texture != null
	)
	_check(
		"every tile has ground",
		renderer.ground.get_used_cells().size() == world.size.x * world.size.y,
		"%d cells" % renderer.ground.get_used_cells().size()
	)
	_check("decals are scattered", renderer.decals.get_child_count() > 0, str(renderer.decals.get_child_count()))
	_check("objects are y-sorted", renderer.object_layer.y_sort_enabled)
	_check(
		"renderer spawned every object",
		renderer.object_layer.get_child_count() == world.objects.size(),
		"%d spawned / %d objects" % [
			renderer.object_layer.get_child_count(), world.objects.size()
		]
	)

	var staged_trees := {}
	var visuals_match := true
	var sprites_loaded := true

	for child in renderer.object_layer.get_children():
		var object_sprite: Sprite2D = child.get_node("Sprite2D")

		if not _texture_loaded(object_sprite.texture):
			sprites_loaded = false

		if not (child is TreeEntity):
			continue

		staged_trees[child.growth_stage] = true

		var expected := _texture_for_stage(child, child.growth_stage)
		if expected == null or not _texture_loaded(expected) or object_sprite.texture != expected:
			visuals_match = false

	_check("spawned trees keep their generated stage", staged_trees.size() >= 2, str(staged_trees.keys()))
	_check("all object sprites have textures", sprites_loaded)
	_check("sprite textures match the growth stage", visuals_match)

	var rebuilt: WorldGrid = main.world_generator.generate_world(WORLD_SEED)
	renderer.display_world(rebuilt)
	await process_frame

	_check(
		"rebuilding the world replaces the old objects",
		renderer.object_layer.get_child_count() == rebuilt.objects.size(),
		"%d spawned / %d objects" % [
			renderer.object_layer.get_child_count(), rebuilt.objects.size()
		]
	)
	_check(
		"rebuilding the world keeps the ground complete",
		renderer.ground.get_used_cells().size() == rebuilt.size.x * rebuilt.size.y,
		"%d cells" % renderer.ground.get_used_cells().size()
	)

	main.queue_free()
	await process_frame


func _texture_loaded(texture: Texture2D) -> bool:
	if texture == null:
		return false

	if texture is AtlasTexture:
		return texture.atlas != null and texture.atlas.get_size() != Vector2.ZERO

	return true


func _texture_for_stage(tree, stage: int) -> Texture2D:
	match stage:
		TreeEntity.TreeStage.SEEDLING:
			return tree.seedling_texture
		TreeEntity.TreeStage.YOUNG:
			return tree.young_texture
		TreeEntity.TreeStage.STUMP:
			return tree.stump_texture
		_:
			return tree.mature_texture
