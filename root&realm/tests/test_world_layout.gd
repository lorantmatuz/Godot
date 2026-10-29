extends "res://tests/_test_case.gd"

# Terrain balance, water banks, forest staging and field plots.


func run() -> void:
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
	check("the camp clearing is soil", camp == WorldGrid.Terrain.SOIL, str(camp))

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

	check("terrain is 64x64", world.size == Vector2i(MAP_SIZE, MAP_SIZE), str(world.size))
	check(
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

	check("the map is mostly grass", grass_share >= 0.55, "%.0f %%" % (grass_share * 100.0))
	check("soil covers part of the map", soil_share >= 0.05, "%.1f %%" % (soil_share * 100.0))
	check("ponds cover part of the map", water_share >= 0.005, "%.2f %%" % (water_share * 100.0))
	check("water keeps a grass bank", bank_ok)
	check("the starting clearing is empty", clearing_empty)
	check("grass uses only kit fill variants", grass_variants_valid)
	check("trees grow only on grass", trees_on_grass)
	check("trees cover several growth stages", stages.size() >= 2, str(stages.keys()))
	check(
		"mature trees pick a kit species",
		species.size() >= 1 and species.keys().all(
			func(s): return s in WorldGenerator.MATURE_SPECIES
		),
		str(species.keys())
	)
	check("only trees, tufts and props exist", unknown_objects == 0, str(unknown_objects))
	check("every scattered prop has a renderer texture", unknown_props == 0, str(unknown_props))
	check("the map has field plots", patch_types.has("field"), str(patch_types.keys()))
	check(
		"every plot keeps a few tufts",
		undersized == 0,
		"thinnest %d of %d plots" % [thinnest, world.patches.size()]
	)
	check("plot objects stay near their plot", objects_outside_patch == 0, str(objects_outside_patch))
	check("plot objects stay inside their own tile", offsets_in_tile)
	check("every plot object has a valid sprite", variants_valid)
	check("tufts are planted on tilled soil", tufts_on_soil)
	check("a grove is reachable from the start", trees_near_start >= 5, str(trees_near_start))
	check("a field is reachable from the start", tufts_near_start >= 10, str(tufts_near_start))

	finish()


func _touches_water(world: WorldGrid, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if world.is_water(x + dx, y + dy):
				return true

	return false
