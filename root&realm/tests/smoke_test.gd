extends SceneTree

# Headless smoke test: godot --headless --path "root&realm" --script res://tests/smoke_test.gd

const WORLD_SEED := 12345
const TILE_SIZE := 32
const MAP_SIZE := 64

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_test_generation()
	_test_layout()
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
	var started := Time.get_ticks_msec()
	var first := WorldGenerator.new().generate_world(WORLD_SEED)
	var second := WorldGenerator.new().generate_world(WORLD_SEED)
	var other := WorldGenerator.new().generate_world(WORLD_SEED + 1)

	_check("same seed reproduces the terrain", first.terrain == second.terrain)
	_check("same seed reproduces the grass variants", first.ground_variant == second.ground_variant)
	_check("same seed reproduces the objects", first.objects == second.objects)
	_check("a different seed moves the terrain", first.terrain != other.terrain)
	_check("a different seed moves the trees and props", first.objects != other.objects)
	print("  info  three worlds generated in %d ms" % (Time.get_ticks_msec() - started))


func _test_layout() -> void:
	print("world layout")
	var world := WorldGenerator.new().generate_world(WORLD_SEED)
	var counts := {}
	var terrain_kinds := {}
	var grass_variants_valid := true
	var bank_ok := true
	var trees_on_grass := true
	var stages := {}
	var species := {}
	var trees_near_start := 0
	var tufts_near_start := 0
	var tufts_on_soil := true
	var offsets_in_tile := true
	var variants_valid := true
	var patch_types := {}
	var objects_per_patch := {}
	var objects_outside_patch := 0
	var unknown_objects := 0
	var unknown_props := 0
	var patches := {}
	var clearing_empty := true
	var center := Vector2(MAP_SIZE, MAP_SIZE) / 2.0

	for y in range(world.size.y):
		for x in range(world.size.x):
			var terrain: WorldGrid.Terrain = world.get_terrain(x, y)
			counts[terrain] = counts.get(terrain, 0) + 1
			terrain_kinds[terrain] = true

			var variant := world.get_ground_variant(x, y)
			if not WorldGenerator.GRASS_VARIANT_POOL.has(variant):
				grass_variants_valid = false

			# No soil may touch water: the kit has no dirt-on-water corner set.
			if terrain != WorldGrid.Terrain.WATER and _touches_water(world, x, y):
				if terrain != WorldGrid.Terrain.GRASS:
					bank_ok = false

	var camp: WorldGrid.Terrain = world.get_terrain(int(center.x), int(center.y))
	_check("the camp clearing is soil", camp == WorldGrid.Terrain.SOIL, str(camp))

	for i in range(world.patches.size()):
		var patch: Dictionary = world.patches[i]
		patches[i] = patch
		patch_types[patch["type"]] = true
		objects_per_patch[i] = 0

	for obj in world.objects:
		var tile := Vector2(obj["x"], obj["y"])
		var terrain: WorldGrid.Terrain = world.get_terrain(obj["x"], obj["y"])

		if tile.distance_to(center) <= WorldGenerator.OBJECT_CLEARING_RADIUS:
			clearing_empty = false

		if obj["type"] == "tree":
			if terrain != WorldGrid.Terrain.GRASS:
				trees_on_grass = false

			stages[obj["stage"]] = true
			if obj.get("species", "") != "":
				species[obj["species"]] = true

			if tile.distance_to(center) <= WorldGenerator.START_RESOURCE_RADIUS:
				trees_near_start += 1

			continue

		if obj["type"] == "prop":
			if not WorldRenderer.PROP_TEXTURES.has(obj["name"]):
				unknown_props += 1
			continue

		if obj["type"] != "tuft":
			unknown_objects += 1
			continue

		# Everything else was planted as part of a field plot.
		var patch_index: int = obj["patch"]
		var patch: Dictionary = patches[patch_index]
		objects_per_patch[patch_index] += 1

		if terrain != WorldGrid.Terrain.SOIL:
			tufts_on_soil = false

		var offset: Vector2 = obj["offset"]
		if absf(offset.x) > 0.5 or absf(offset.y) > 0.5:
			offsets_in_tile = false

		if tile.distance_to(Vector2(patch["x"], patch["y"])) > float(patch["radius"]) + 1.0:
			objects_outside_patch += 1

		var variant: int = obj["variant"]
		if variant < 0 or variant >= WorldGenerator.TUFT_VARIANTS:
			variants_valid = false

		if tile.distance_to(center) <= WorldGenerator.START_RESOURCE_RADIUS:
			tufts_near_start += 1

	var thinnest := 1 << 30
	var undersized := 0

	for i in range(world.patches.size()):
		thinnest = mini(thinnest, objects_per_patch[i])

		if objects_per_patch[i] < WorldGenerator.PATCH_MIN_TUFTS:
			undersized += 1

	_check("terrain is 64x64", world.size == Vector2i(MAP_SIZE, MAP_SIZE), str(world.size))
	_check(
		"the ground is grass, soil and water",
		terrain_kinds.size() == 3
		and terrain_kinds.has(WorldGrid.Terrain.GRASS)
		and terrain_kinds.has(WorldGrid.Terrain.SOIL)
		and terrain_kinds.has(WorldGrid.Terrain.WATER),
		str(terrain_kinds.keys())
	)
	var total := float(world.size.x * world.size.y)
	var grass_share := float(counts.get(WorldGrid.Terrain.GRASS, 0)) / total
	var soil_share := float(counts.get(WorldGrid.Terrain.SOIL, 0)) / total
	var water_share := float(counts.get(WorldGrid.Terrain.WATER, 0)) / total

	_check("the map is mostly grass", grass_share >= 0.55, "%.0f %%" % (grass_share * 100.0))
	_check("soil covers part of the map", soil_share >= 0.05, "%.1f %%" % (soil_share * 100.0))
	_check("ponds cover part of the map", water_share >= 0.005, "%.2f %%" % (water_share * 100.0))
	_check("water keeps a grass bank", bank_ok)
	_check("the starting clearing is empty", clearing_empty)
	_check("grass uses only kit fill variants", grass_variants_valid)
	_check("trees grow only on grass", trees_on_grass)
	_check("trees cover several growth stages", stages.size() >= 2, str(stages.keys()))
	_check(
		"mature trees pick a kit species",
		species.size() >= 1 and species.keys().all(
			func(s): return s in WorldGenerator.MATURE_SPECIES
		),
		str(species.keys())
	)
	_check("only trees, tufts and props exist", unknown_objects == 0, str(unknown_objects))
	_check("every scattered prop has a renderer texture", unknown_props == 0, str(unknown_props))
	_check("the map has field plots", patch_types.has("field"), str(patch_types.keys()))
	_check(
		"every plot keeps a few tufts",
		undersized == 0,
		"thinnest %d of %d plots" % [thinnest, world.patches.size()]
	)
	_check("plot objects stay near their plot", objects_outside_patch == 0, str(objects_outside_patch))
	_check("plot objects stay inside their own tile", offsets_in_tile)
	_check("every plot object has a valid sprite", variants_valid)
	_check("tufts are planted on tilled soil", tufts_on_soil)
	_check("a grove is reachable from the start", trees_near_start >= 5, str(trees_near_start))
	_check("a field is reachable from the start", tufts_near_start >= 10, str(tufts_near_start))


func _touches_water(world: WorldGrid, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if world.is_water(x + dx, y + dy):
				return true

	return false


func _test_camera_bounds() -> void:
	print("camera bounds")
	var scene: PackedScene = load("res://scenes/levels/main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame

	var camera: Camera2D = main.get_node("Camera2D")
	var max_position := _camera_max_position(camera)

	_check("camera starts zoomed to whole pixels at 2x", camera.zoom == Vector2(2.0, 2.0), str(camera.zoom))

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
	var started := Time.get_ticks_msec()
	root.add_child(main)
	await process_frame
	print("  info  world build (generate + fill + blends + glints): %d ms" % (Time.get_ticks_msec() - started))

	var camera: Camera2D = main.get_node("Camera2D")
	var world_size := MAP_SIZE * TILE_SIZE

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

	_check("the shader ground is gone", renderer.get("ground") == null)
	_check("the grass fill covers every tile", renderer.fill_layer.get_used_cells().size() == MAP_SIZE * MAP_SIZE,
		"%d cells" % renderer.fill_layer.get_used_cells().size())
	_check(
		"fill cells use the generated grass variants",
		_fill_matches_variants(renderer)
	)
	_check("objects are y-sorted", renderer.object_layer.y_sort_enabled)
	_check(
		"renderer spawned every object",
		renderer.object_layer.get_child_count() == world.objects.size(),
		"%d spawned / %d objects" % [
			renderer.object_layer.get_child_count(), world.objects.size()
		]
	)

	_check("soil has a dual-grid display layer", renderer.soil_display is DualGridLayer)
	_check("water has a dual-grid display layer", renderer.water_display is DualGridLayer)
	_check(
		"soil display draws the grass↔dirt atlas",
		renderer.soil_display.atlas_json == WorldRenderer.SOIL_ATLAS
		and FileAccess.file_exists(WorldRenderer.SOIL_ATLAS)
		and renderer.soil_display.tile_set == WorldRenderer.SOIL_TILESET
	)
	_check(
		"water display draws the grass↔water atlas",
		renderer.water_display.atlas_json == WorldRenderer.WATER_ATLAS
		and FileAccess.file_exists(WorldRenderer.WATER_ATLAS)
		and renderer.water_display.tile_set == WorldRenderer.WATER_TILESET
	)
	_check(
		"display layers only draw blends, not pure grass",
		renderer.soil_display.skip_codes.has("llll")
		and renderer.water_display.skip_codes.has("llll")
	)
	_check(
		"display layers do not poll for edits",
		renderer.soil_display.poll_seconds == 0.0
		and renderer.water_display.poll_seconds == 0.0
	)
	_check("soil blend tiles are placed", renderer.soil_display.get_used_cells().size() > 0,
		"%d cells" % renderer.soil_display.get_used_cells().size())
	_check("water blend tiles are placed", renderer.water_display.get_used_cells().size() > 0,
		"%d cells" % renderer.water_display.get_used_cells().size())
	_check(
		"soil corner codes follow the terrain",
		_display_matches_terrain(renderer, renderer.soil_display, WorldGrid.Terrain.SOIL)
	)
	_check(
		"water corner codes follow the terrain",
		_display_matches_terrain(renderer, renderer.water_display, WorldGrid.Terrain.WATER)
	)
	_check(
		"glints animate the water display layer",
		renderer.glints != null and renderer.glints.water == renderer.water_display
	)
	print("  info  water glints scattered: %d" % renderer.glints.get("_glints").size())

	var textures_loaded := true
	var anchored := true
	var visuals_match := true
	var foot_positions_match := true
	var object_types := {}

	for i in range(world.objects.size()):
		var obj_data: Dictionary = world.objects[i]
		var node: Node = renderer.object_layer.get_child(i)

		object_types[obj_data["type"]] = true

		var sprite: Sprite2D
		var expected: Texture2D

		if node is TreeEntity:
			sprite = node.get_node("Sprite2D")
			expected = renderer.tree_texture(node.growth_stage, node.species)
			if node.growth_stage != obj_data["stage"] or node.species != obj_data.get("species", ""):
				visuals_match = false
		else:
			sprite = node
			expected = WorldRenderer.PROP_TEXTURES.get(obj_data["name"])

		if sprite.texture == null or expected == null or sprite.texture != expected:
			textures_loaded = false
		if sprite.centered or sprite.offset != Vector2(-sprite.texture.get_width() / 2.0, -sprite.texture.get_height()):
			anchored = false
		if not node.position.is_equal_approx(_expected_foot(obj_data)):
			foot_positions_match = false

	_check("all object sprites have textures", textures_loaded)
	_check("tree sprites match the growth stage and species", visuals_match)
	_check("props are anchored at their bottom centre", anchored)
	_check("objects sit on their tile foot", foot_positions_match)
	_check(
		"only trees, tufts and props are spawned",
		object_types.size() <= 3
		and object_types.has("tree")
		and (object_types.has("tuft") or object_types.has("prop")),
		str(object_types.keys())
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
		"rebuilding the world repaints the blends",
		_display_matches_terrain(renderer, renderer.soil_display, WorldGrid.Terrain.SOIL)
		and _display_matches_terrain(renderer, renderer.water_display, WorldGrid.Terrain.WATER)
	)

	main.queue_free()
	await process_frame


func _fill_matches_variants(renderer) -> bool:
	var world: WorldGrid = renderer.world

	for y in range(world.size.y):
		for x in range(world.size.x):
			var cell := Vector2i(x, y)
			var expected := Vector2i(world.get_ground_variant(x, y), 0)

			if not renderer.fill_layer.get_used_cells().has(cell):
				return false
			if renderer.fill_layer.get_cell_atlas_coords(cell) != expected:
				return false

	return true


func _display_matches_terrain(
	renderer,
	display: DualGridLayer,
	kind: WorldGrid.Terrain
) -> bool:
	# The dual grid labels a display cell by the four world cells around it:
	# NW, NE, SE, SW. Recompute every code from the terrain and compare.
	var world: WorldGrid = renderer.world
	var used := display.get_used_cells()

	if used.is_empty():
		return false

	for cell in used:
		var code := ""

		for corner in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(-1, 0)]:
			var c: Vector2i = cell + corner
			code += "u" if world.get_terrain(c.x, c.y) == kind else "l"

		var expected := display.code_coords(code)
		if expected == Vector2i(-1, -1):
			return false
		if display.get_cell_atlas_coords(cell) != expected:
			return false

	return true


func _expected_foot(obj_data: Dictionary) -> Vector2:
	var offset: Vector2 = obj_data.get("offset", Vector2.ZERO) * TILE_SIZE

	return Vector2(
		(obj_data["x"] + 0.5) * TILE_SIZE,
		(obj_data["y"] + 1.0) * TILE_SIZE
	) + offset
