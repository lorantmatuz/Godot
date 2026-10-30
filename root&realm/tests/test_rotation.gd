extends "res://tests/_test_case.gd"

# Rotating the map a quarter turn: terrain, ground variants, object tiles, art
# offsets, building footprints, and the round trip back to the same map.

const MAP := 6


func run() -> void:
	print("rotation")
	_test_terrain()
	_test_objects()
	_test_offsets()
	_test_buildings()
	_test_round_trip()
	finish()


func _world() -> WorldGrid:
	return WorldGrid.new(Vector2i(MAP, MAP))


func _test_terrain() -> void:
	var world := _world()
	world.set_terrain(1, 2, WorldGrid.Terrain.SOIL)
	world.set_terrain(4, 0, WorldGrid.Terrain.WATER)
	world.set_ground_variant(1, 2, 7)

	world.rotate_quarter_turn()

	check(
		"a clockwise turn moves the terrain with it",
		world.get_terrain(3, 1) == WorldGrid.Terrain.SOIL
		and world.get_terrain(5, 4) == WorldGrid.Terrain.WATER
		and world.get_terrain(1, 2) == WorldGrid.Terrain.GRASS,
		"%s %s" % [world.get_terrain(3, 1), world.get_terrain(5, 4)]
	)
	check("the grass variant turns with its tile", world.get_ground_variant(3, 1) == 7)

	var back := _world()
	back.set_terrain(1, 2, WorldGrid.Terrain.SOIL)
	back.rotate_quarter_turn(false)
	check(
		"a counter-clockwise turn goes the other way",
		back.get_terrain(2, 4) == WorldGrid.Terrain.SOIL
		and back.get_terrain(1, 2) == WorldGrid.Terrain.GRASS
	)


func _test_objects() -> void:
	var world := _world()
	var id := world.add_object({"type": "prop", "name": "mossy_rock", "x": 1, "y": 2})

	world.rotate_quarter_turn()

	var data: Dictionary = world.objects_by_id[id]
	var tile := Vector2i(data["x"], data["y"])
	var ids: Array = world.objects_by_tile.get(tile, [])

	check(
		"an object keeps its id and moves to the turned tile",
		tile == Vector2i(3, 1) and not world.objects_by_tile.has(Vector2i(1, 2)),
		str(tile)
	)
	check(
		"the tile index is rebuilt from the new positions",
		ids.size() == 1 and ids[0] == id and not world.objects_by_tile.has(Vector2i(1, 2)),
		"%d entries" % world.objects_by_tile.size()
	)


func _test_offsets() -> void:
	var world := _world()
	var id := world.add_object({
		"type": "tuft",
		"name": "tall_grass_tuft",
		"x": 2,
		"y": 2,
		"offset": Vector2(0.4, 0.0),
	})

	world.rotate_quarter_turn()

	var offset: Vector2 = world.objects_by_id[id]["offset"]
	check(
		"an art offset turns with the sprite it nudges",
		offset.is_equal_approx(Vector2(0.0, 0.4)),
		str(offset)
	)


func _test_buildings() -> void:
	var world := _world()
	var id := world.add_building("house", Vector2i(1, 1), Vector2i(2, 2))

	world.rotate_quarter_turn()

	var data: Dictionary = world.objects_by_id[id]
	check(
		"a building lands on the corner its footprint turns onto",
		Vector2i(data["x"], data["y"]) == Vector2i(3, 1)
		and data["size"] == Vector2i(2, 2)
		and world.building_at(Vector2i(3, 1)) == id
		and world.building_at(Vector2i(4, 2)) == id,
		"%s %s" % [Vector2i(data["x"], data["y"]), data["size"]]
	)
	check(
		"the old footprint is released, not left behind",
		world.building_at(Vector2i(1, 1)) == -1 and world.buildings_by_tile.size() == 4,
		"%d tiles" % world.buildings_by_tile.size()
	)

	# Only square buildings exist today, but the transform must not assume it.
	var wide := _world()
	var wide_id := wide.add_building("test", Vector2i(0, 0), Vector2i(2, 3))
	wide.rotate_quarter_turn()

	var wide_data: Dictionary = wide.objects_by_id[wide_id]
	check(
		"a non-square footprint swaps its sides",
		wide_data["size"] == Vector2i(3, 2)
		and Vector2i(wide_data["x"], wide_data["y"]) == Vector2i(3, 0),
		"%s %s" % [Vector2i(wide_data["x"], wide_data["y"]), wide_data["size"]]
	)


func _test_round_trip() -> void:
	var world: WorldGrid = WorldGenerator.new().generate_world(WORLD_SEED)
	var terrain := world.terrain.duplicate()
	var variants := world.ground_variant.duplicate()
	var layout := _layout(world)

	for i in range(4):
		world.rotate_quarter_turn()

	check(
		"four turns put the generated map back exactly",
		world.terrain == terrain
		and world.ground_variant == variants
		and _layout(world) == layout,
		"%d objects" % layout.size()
	)

	var back: WorldGrid = WorldGenerator.new().generate_world(WORLD_SEED)
	back.rotate_quarter_turn()
	back.rotate_quarter_turn(false)
	check(
		"a clockwise turn and a counter-clockwise turn cancel out",
		back.terrain == terrain and _layout(back) == layout
	)


func _layout(world: WorldGrid) -> Dictionary:
	# Tile and art offset per id: the whole of where an object draws.
	var layout := {}

	for data in world.objects:
		layout[data["id"]] = [
			Vector2i(data["x"], data["y"]),
			data.get("offset", Vector2.ZERO),
		]

	return layout
