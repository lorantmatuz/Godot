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
	var tufts_on_grass := true
	var trees_near_start := 0
	var stones_near_start := 0
	var tufts_near_start := 0
	var stages := {}
	var offsets_in_tile := true
	var stone_variants := {}
	var tuft_variants := {}
	var stone_spots := {}
	var variants_valid := true
	var patches := {}
	var patch_types := {}
	var objects_per_patch := {}
	var objects_outside_patch := 0

	for y in range(world.size.y):
		for x in range(world.size.x):
			var terrain: WorldGrid.Terrain = world.get_terrain(x, y)
			counts[terrain] = counts.get(terrain, 0) + 1

			if Vector2(x, y).distance_to(center) <= WorldGenerator.CLEARING_RADIUS:
				if terrain != WorldGrid.Terrain.GRASS:
					clearing_grass = false

	for i in range(world.patches.size()):
		var patch: Dictionary = world.patches[i]
		patches[i] = patch
		patch_types[patch["type"]] = true
		objects_per_patch[i] = 0

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

			continue

		# Everything else was planted as part of a resource patch.
		var patch_index: int = obj["patch"]
		var patch: Dictionary = patches[patch_index]
		objects_per_patch[patch_index] += 1

		# Offsets are a share of the tile, so the object stays on its own tile.
		var offset: Vector2 = obj["offset"]
		if absf(offset.x) > 0.5 or absf(offset.y) > 0.5:
			offsets_in_tile = false

		if tile.distance_to(Vector2(patch["x"], patch["y"])) > float(patch["radius"]) + 1.0:
			objects_outside_patch += 1

		if obj["type"] == "stone":
			if terrain != WorldGrid.Terrain.ROCKY:
				stones_on_rock = false

			var variant: int = obj["variant"]

			if variant < 0 or variant >= WorldGenerator.ROCK_VARIANTS:
				variants_valid = false
			stone_variants[variant] = true

			if not stone_spots.has(patch_index):
				stone_spots[patch_index] = []
			stone_spots[patch_index].append(tile + offset)

			if tile.distance_to(center) <= WorldGenerator.START_RESOURCE_RADIUS:
				stones_near_start += 1
		elif obj["type"] == "tuft":
			if terrain != WorldGrid.Terrain.GRASS:
				tufts_on_grass = false

			var variant: int = obj["variant"]

			if variant < 0 or variant >= WorldGenerator.TUFT_VARIANTS:
				variants_valid = false
			tuft_variants[variant] = true

			if tile.distance_to(center) <= WorldGenerator.START_RESOURCE_RADIUS:
				tufts_near_start += 1

	_check("terrain is 64x64", world.size == Vector2i(64, 64), str(world.size))
	_check(
		"water, grass, forest, and rock are all present",
		counts.has(WorldGrid.Terrain.WATER)
		and counts.has(WorldGrid.Terrain.GRASS)
		and counts.has(WorldGrid.Terrain.FOREST_FLOOR)
		and counts.has(WorldGrid.Terrain.ROCKY),
		str(counts)
	)
	var thinnest := 1 << 30
	var undersized := 0

	for i in range(world.patches.size()):
		var count: int = objects_per_patch[i]

		thinnest = mini(thinnest, count)

		if patches[i]["type"] == "meadow":
			if count < WorldGenerator.PATCH_MIN_TUFTS:
				undersized += 1
		elif count < WorldGenerator.QUARRY_MIN_STONES or count > WorldGenerator.QUARRY_MAX_STONES:
			undersized += 1

	# A quarry is one rubble field, so no stone may sit apart from the rest: every
	# stone needs a neighbour closer than half a tile.
	var isolated_stones := 0

	for patch_index in stone_spots:
		var spots: Array = stone_spots[patch_index]

		for spot in spots:
			var nearest := 1e9

			for other in spots:
				var distance: float = spot.distance_to(other)

				if distance > 0.001 and distance < nearest:
					nearest = distance

			if nearest > 0.5:
				isolated_stones += 1

	_check("the starting clearing is grass", clearing_grass)
	_check("the starting clearing is empty", clearing_empty)
	_check("no objects are placed in water", objects_in_water == 0, str(objects_in_water))
	_check("trees grow on grass or forest floor", trees_on_land)
	_check("stones sit on rocky ground", stones_on_rock)
	_check("grass tufts grow on grass", tufts_on_grass)
	_check(
		"the map has both meadows and quarries",
		patch_types.has("meadow") and patch_types.has("quarry"),
		str(patch_types.keys())
	)
	_check(
		"every patch is a dense unit",
		undersized == 0,
		"thinnest %d of %d patches" % [thinnest, world.patches.size()]
	)
	_check("patch objects stay near their patch", objects_outside_patch == 0, str(objects_outside_patch))
	_check("patch objects stay inside their own tile", offsets_in_tile)
	_check("every patch object has a valid sprite", variants_valid)
	_check("every stone touches another stone", isolated_stones == 0, str(isolated_stones))
	_check(
		"stones use every rock sprite",
		stone_variants.size() == WorldGenerator.ROCK_VARIANTS,
		str(stone_variants.keys())
	)
	_check(
		"tufts use every grass sprite",
		tuft_variants.size() == WorldGenerator.TUFT_VARIANTS,
		str(tuft_variants.keys())
	)
	_check("a grove is reachable from the start", trees_near_start >= 5, str(trees_near_start))
	_check("a quarry is reachable from the start", stones_near_start >= 10, str(stones_near_start))
	_check("a meadow is reachable from the start", tufts_near_start >= 10, str(tufts_near_start))
	_check("trees are spread across growth stages", stages.size() >= 2, str(stages.keys()))


func _ground_shader(renderer) -> Shader:
	var material := renderer.ground.material as ShaderMaterial

	return material.shader if material != null else null


func _ground_terrain_size(renderer) -> Vector2i:
	var material := renderer.ground.material as ShaderMaterial

	if material == null:
		return Vector2i.ZERO

	var texture: ImageTexture = material.get_shader_parameter("terrain_tex")
	if texture == null:
		return Vector2i.ZERO

	return Vector2i(texture.get_size())


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

	_check("ground is a single sprite", renderer.ground is Sprite2D)
	_check("ground is drawn by a shader", _ground_shader(renderer) != null)
	_check(
		"ground covers the world",
		renderer.ground.scale == Vector2(world.size) * WorldRenderer.TILE_SIZE,
		str(renderer.ground.scale)
	)
	_check(
		"ground terrain texture matches the world",
		_ground_terrain_size(renderer) == world.size,
		str(_ground_terrain_size(renderer))
	)
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
	var tuft_visuals_match := true
	var stone_visuals_match := true
	var tuft_textures := {}
	var stone_textures := {}

	for i in range(world.objects.size()):
		var obj_data: Dictionary = world.objects[i]
		var node: Node = renderer.object_layer.get_child(i)

		if node is TreeEntity:
			var tree_sprite: Sprite2D = node.get_node("Sprite2D")
			var expected := _texture_for_stage(node, node.growth_stage)

			staged_trees[node.growth_stage] = true
			if not _texture_loaded(tree_sprite.texture):
				sprites_loaded = false
			if expected == null or not _texture_loaded(expected) or tree_sprite.texture != expected:
				visuals_match = false
			continue

		if obj_data["type"] == "tuft":
			var tuft_sprite: Sprite2D = node.get_node("Sprite2D")
			var tuft_texture: Texture2D = WorldRenderer.GRASS_TEXTURES[obj_data["variant"]]

			if not _texture_loaded(tuft_sprite.texture):
				sprites_loaded = false
			if tuft_sprite.texture != tuft_texture or tuft_sprite.flip_h != bool(obj_data["flip"]):
				tuft_visuals_match = false
			tuft_textures[tuft_texture] = true
			continue

		var stone_sprite: Sprite2D = node.get_node("Sprite2D")
		var stone_texture: Texture2D = WorldRenderer.ROCK_TEXTURES[obj_data["variant"]]

		if not _texture_loaded(stone_sprite.texture):
			sprites_loaded = false
		if stone_sprite.texture != stone_texture or stone_sprite.flip_h != bool(obj_data["flip"]):
			stone_visuals_match = false
		stone_textures[stone_texture] = true

	_check("spawned trees keep their generated stage", staged_trees.size() >= 2, str(staged_trees.keys()))
	_check("all object sprites have textures", sprites_loaded)
	_check("sprite textures match the growth stage", visuals_match)
	_check("spawned tufts keep their generated variant", tuft_visuals_match)
	_check("spawned stones keep their generated variant", stone_visuals_match)
	_check(
		"grass tufts use every grass sprite",
		tuft_textures.size() == WorldRenderer.GRASS_TEXTURES.size(),
		"%d of %d" % [tuft_textures.size(), WorldRenderer.GRASS_TEXTURES.size()]
	)
	_check(
		"stones use every rock sprite in the scene",
		stone_textures.size() == WorldRenderer.ROCK_TEXTURES.size(),
		"%d of %d" % [stone_textures.size(), WorldRenderer.ROCK_TEXTURES.size()]
	)

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
		"rebuilding the world rebuilds the ground",
		_ground_terrain_size(renderer) == rebuilt.size
		and renderer.ground.scale == Vector2(rebuilt.size) * WorldRenderer.TILE_SIZE,
		str(_ground_terrain_size(renderer))
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
