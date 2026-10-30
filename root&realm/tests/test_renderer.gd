extends "res://tests/_test_case.gd"

# The main scene's rendering: fill layer, dual-grid blends, glints, spawned
# sprites and a rebuild.


func run() -> void:
	print("main scene")
	var scene: PackedScene = load("res://scenes/levels/main.tscn")
	var main = scene.instantiate()
	var started := Time.get_ticks_msec()
	root.add_child(main)
	await process_frame
	print(
		"  info  world build (generate + fill + blends + glints): %d ms"
		% (Time.get_ticks_msec() - started)
	)

	var renderer = main.world_renderer
	var world: WorldGrid = renderer.world

	check("the shader ground is gone", renderer.get("ground") == null)
	check(
		"the grass fill covers every tile",
		renderer.fill_layer.get_used_cells().size() == MAP_SIZE * MAP_SIZE,
		"%d cells" % renderer.fill_layer.get_used_cells().size()
	)
	check(
		"fill cells use the generated grass variants",
		_fill_matches_variants(renderer)
	)
	check("objects are y-sorted", renderer.object_layer.y_sort_enabled)
	check(
		"renderer spawned every object",
		renderer.object_layer.get_child_count() == world.objects.size(),
		"%d spawned / %d objects" % [
			renderer.object_layer.get_child_count(), world.objects.size()
		]
	)

	check("soil has a dual-grid display layer", renderer.soil_display is DualGridLayer)
	check("water has a dual-grid display layer", renderer.water_display is DualGridLayer)
	check(
		"soil display draws the grass↔dirt atlas",
		renderer.soil_display.atlas_json == WorldRenderer.SOIL_ATLAS
		and FileAccess.file_exists(WorldRenderer.SOIL_ATLAS)
		and renderer.soil_display.tile_set == WorldRenderer.SOIL_TILESET
	)
	check(
		"water display draws the grass↔water atlas",
		renderer.water_display.atlas_json == WorldRenderer.WATER_ATLAS
		and FileAccess.file_exists(WorldRenderer.WATER_ATLAS)
		and renderer.water_display.tile_set == WorldRenderer.WATER_TILESET
	)
	check(
		"display layers only draw blends, not pure grass",
		renderer.soil_display.skip_codes.has("llll")
		and renderer.water_display.skip_codes.has("llll")
	)
	check(
		"display layers do not poll for edits",
		renderer.soil_display.poll_seconds == 0.0
		and renderer.water_display.poll_seconds == 0.0
	)
	check("soil blend tiles are placed", renderer.soil_display.get_used_cells().size() > 0,
		"%d cells" % renderer.soil_display.get_used_cells().size())
	check("water blend tiles are placed", renderer.water_display.get_used_cells().size() > 0,
		"%d cells" % renderer.water_display.get_used_cells().size())
	check(
		"soil corner codes follow the terrain",
		_display_matches_terrain(renderer, renderer.soil_display, WorldGrid.Terrain.SOIL)
	)
	check(
		"water corner codes follow the terrain",
		_display_matches_terrain(renderer, renderer.water_display, WorldGrid.Terrain.WATER)
	)
	check(
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
		var anchor := Vector2(
			-sprite.texture.get_width() / 2.0,
			-sprite.texture.get_height()
		)

		if sprite.centered or sprite.offset != anchor:
			anchored = false
		if not node.position.is_equal_approx(_expected_foot(obj_data)):
			foot_positions_match = false

	check("all object sprites have textures", textures_loaded)
	check("tree sprites match the growth stage and species", visuals_match)
	check("props are anchored at their bottom centre", anchored)
	check("objects sit on their tile foot", foot_positions_match)
	check(
		"only trees, tufts and props are spawned",
		object_types.size() <= 3
		and object_types.has("tree")
		and (object_types.has("tuft") or object_types.has("prop")),
		str(object_types.keys())
	)

	check(
		"the blend-edge fill is the atlases' own grass tile",
		_fill_matches_atlas_grass(WorldGenerator.BLEND_EDGE_VARIANT)
	)

	var rebuilt: WorldGrid = main.world_generator.generate_world(WORLD_SEED)
	renderer.display_world(rebuilt)
	await process_frame

	check(
		"rebuilding the world replaces the old objects",
		renderer.object_layer.get_child_count() == rebuilt.objects.size(),
		"%d spawned / %d objects" % [
			renderer.object_layer.get_child_count(), rebuilt.objects.size()
		]
	)
	check(
		"rebuilding the world rebuilds the id map",
		renderer.object_nodes.size() == rebuilt.objects.size(),
		"%d ids / %d objects" % [renderer.object_nodes.size(), rebuilt.objects.size()]
	)
	check(
		"rebuilding the world repaints the blends",
		_display_matches_terrain(renderer, renderer.soil_display, WorldGrid.Terrain.SOIL)
		and _display_matches_terrain(renderer, renderer.water_display, WorldGrid.Terrain.WATER)
	)

	main.queue_free()
	await process_frame
	finish()


func _fill_matches_atlas_grass(variant: int) -> bool:
	# The blend layers replace whole quadrants of the fill, so the variants they
	# cut must be the same art as the atlases' pure-grass tile ("llll" at 0,0).
	var fills: Image = WorldRenderer.FILL_TILESET.get_source(0).texture.get_image()
	var fill := fills.get_region(Rect2i(variant * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE))

	for tileset in [WorldRenderer.SOIL_TILESET, WorldRenderer.WATER_TILESET]:
		var atlas: Image = tileset.get_source(0).texture.get_image()
		var grass := atlas.get_region(Rect2i(0, 0, TILE_SIZE, TILE_SIZE))

		for y in range(TILE_SIZE):
			for x in range(TILE_SIZE):
				if fill.get_pixel(x, y) != grass.get_pixel(x, y):
					return false

	return true


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
