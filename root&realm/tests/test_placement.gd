extends "res://tests/_test_case.gd"

# Placement: footprints, ground rules, clearance, site radii, and the ghost that
# previews a building before it is committed.

const MAP := 16


func run() -> void:
	print("placement")
	_test_footprints()
	_test_ground_rules()
	_test_clearance()
	_test_cover()
	_test_site_requirements()
	await _test_ghost_and_commit()


func _world() -> WorldGrid:
	return WorldGrid.new(Vector2i(MAP, MAP))


func _tree(world: WorldGrid, tile: Vector2i, stage: int = TreeEntity.TreeStage.MATURE) -> void:
	world.add_object({
		"type": "tree",
		"x": tile.x,
		"y": tile.y,
		"stage": stage,
		"species": "oak" if stage == TreeEntity.TreeStage.MATURE else "",
	})


func _paint(world: WorldGrid, tiles: Array[Vector2i], terrain: WorldGrid.Terrain) -> void:
	for tile in tiles:
		world.set_terrain(tile.x, tile.y, terrain)


func _test_footprints() -> void:
	var camp := Placement.footprint_tiles("camp", Vector2i(3, 4))
	var house := Placement.footprint_tiles("house", Vector2i(3, 4))

	check(
		"a 1x1 building covers exactly its anchor tile",
		camp.size() == 1 and camp[0] == Vector2i(3, 4),
		str(camp)
	)
	check(
		"a 2x2 building covers its whole footprint, not just the anchor",
		house.size() == 4
		and house.has(Vector2i(3, 4))
		and house.has(Vector2i(4, 4))
		and house.has(Vector2i(3, 5))
		and house.has(Vector2i(4, 5)),
		str(house)
	)
	check(
		"an unknown building has no footprint",
		Placement.footprint_tiles("castle", Vector2i.ZERO).is_empty()
	)


func _test_ground_rules() -> void:
	var world := _world()

	check(
		"an empty grass map takes a camp",
		Placement.can_place(world, "camp", Vector2i(5, 5)) == Placement.Reason.OK
	)

	world.set_terrain(5, 5, WorldGrid.Terrain.WATER)
	check(
		"water refuses a building",
		Placement.can_place(world, "camp", Vector2i(5, 5)) == Placement.Reason.TERRAIN
	)

	check(
		"the map edge refuses a building",
		Placement.can_place(world, "camp", Vector2i(MAP, 0)) == Placement.Reason.OUT_OF_BOUNDS
		and Placement.can_place(world, "camp", Vector2i(-1, -1))
		== Placement.Reason.OUT_OF_BOUNDS
	)

	# One water tile is enough to sink a 2x2 footprint, and it is reported even
	# though the other three tiles are fine.
	world.set_terrain(8, 8, WorldGrid.Terrain.WATER)
	check(
		"one bad corner refuses the whole footprint",
		Placement.can_place(world, "house", Vector2i(7, 7)) == Placement.Reason.TERRAIN
	)

	world.set_terrain(5, 5, WorldGrid.Terrain.SOIL)
	check(
		"the woodcutter wants grass, not a dirt trail",
		Placement.can_place(world, "woodcutter", Vector2i(5, 5)) == Placement.Reason.TERRAIN
		and Placement.can_place(world, "house", Vector2i(4, 4)) == Placement.Reason.OK
	)

	check(
		"an unknown building is refused by name",
		Placement.can_place(world, "castle", Vector2i(5, 5)) == Placement.Reason.UNKNOWN
		and Placement.reason_text(Placement.Reason.UNKNOWN) != ""
	)


func _test_clearance() -> void:
	var world := _world()

	_tree(world, Vector2i(6, 6))
	check(
		"a tree blocks the tile it stands on",
		Placement.can_place(world, "camp", Vector2i(6, 6)) == Placement.Reason.OCCUPIED
	)
	check(
		"a house cannot straddle a tree",
		Placement.can_place(world, "house", Vector2i(5, 5)) == Placement.Reason.OCCUPIED
	)
	check(
		"a tree outside the footprint does not block",
		Placement.can_place(world, "house", Vector2i(7, 7)) == Placement.Reason.OK
	)

	var camp_id := world.add_building("camp", Vector2i(2, 2), Vector2i.ONE)
	var house_id := world.add_building("house", Vector2i(9, 9), Vector2i(2, 2))

	check(
		"a building is indexed across its footprint",
		world.building_at(Vector2i(2, 2)) == camp_id
		and world.building_at(Vector2i(9, 9)) == house_id
		and world.building_at(Vector2i(10, 10)) == house_id
		and world.building_at(Vector2i(11, 11)) == -1,
		"%d %d" % [world.building_at(Vector2i(9, 9)), world.building_at(Vector2i(10, 10))]
	)
	check(
		"an existing building blocks a second one",
		Placement.can_place(world, "house", Vector2i(10, 10)) == Placement.Reason.OCCUPIED
		and Placement.can_place(world, "camp", Vector2i(2, 2)) == Placement.Reason.OCCUPIED
	)

	world.remove_object(house_id)
	check(
		"removing a building frees every footprint tile",
		world.building_at(Vector2i(9, 9)) == -1
		and world.building_at(Vector2i(10, 10)) == -1
		and Placement.can_place(world, "house", Vector2i(9, 9)) == Placement.Reason.OK
	)


func _test_cover() -> void:
	var world := _world()

	world.add_object({"type": "tuft", "name": "tall_grass_tuft", "x": 3, "y": 3})
	world.add_object({"type": "prop", "name": "red_mushrooms", "x": 4, "y": 3})
	world.add_object({"type": "prop", "name": "blue_flowers_patch", "x": 5, "y": 3})

	check(
		"ground cover does not veto a building",
		Placement.can_place(world, "camp", Vector2i(3, 3)) == Placement.Reason.OK
		and Placement.can_place(world, "camp", Vector2i(4, 3)) == Placement.Reason.OK
		and Placement.can_place(world, "camp", Vector2i(5, 3)) == Placement.Reason.OK
	)

	world.add_object({"type": "prop", "name": "mossy_rock", "x": 6, "y": 3})
	world.add_object({"type": "prop", "name": "berry_bush", "x": 7, "y": 3})

	check(
		"a rock or a bush still blocks its tile",
		Placement.can_place(world, "camp", Vector2i(6, 3)) == Placement.Reason.OCCUPIED
		and Placement.can_place(world, "camp", Vector2i(7, 3)) == Placement.Reason.OCCUPIED
	)


func _test_site_requirements() -> void:
	var world := _world()
	var hut := Vector2i(8, 8)

	check(
		"a woodcutter with no forest is refused",
		Placement.can_place(world, "woodcutter", hut) == Placement.Reason.MISSING_TREES
	)

	for tile in [Vector2i(10, 8), Vector2i(12, 8), Vector2i(8, 10), Vector2i(8, 12)]:
		_tree(world, tile)

	check(
		"four trees are not five",
		Placement.can_place(world, "woodcutter", hut) == Placement.Reason.MISSING_TREES
	)

	_tree(world, Vector2i(11, 11))
	check(
		"five mature trees in reach make a woodcutter site",
		Placement.can_place(world, "woodcutter", hut) == Placement.Reason.OK
	)

	world = _world()

	var grove: Array[Vector2i] = [
		Vector2i(10, 8),
		Vector2i(12, 8),
		Vector2i(8, 10),
		Vector2i(8, 12),
		Vector2i(11, 11),
	]

	for tile in grove:
		_tree(world, tile, TreeEntity.TreeStage.YOUNG)

	check(
		"young trees do not count towards the site",
		Placement.can_place(world, "woodcutter", hut) == Placement.Reason.MISSING_TREES
	)

	world = _world()

	# Everything here is more than six tiles from the hut.
	var distant: Array[Vector2i] = [
		Vector2i(15, 6),
		Vector2i(15, 8),
		Vector2i(15, 10),
		Vector2i(15, 12),
		Vector2i(15, 14),
	]

	for tile in distant:
		_tree(world, tile)

	check(
		"trees out of reach do not count",
		Placement.can_place(world, "woodcutter", hut) == Placement.Reason.MISSING_TREES
	)

	world = _world()

	check(
		"a farm with no field is refused",
		Placement.can_place(world, "farm", hut) == Placement.Reason.MISSING_SOIL
	)

	# Eight tiles, every one inside four tiles of the farm's centre (9, 9) and
	# none of them under its 2x2 footprint.
	var field: Array[Vector2i] = [
		Vector2i(10, 9),
		Vector2i(11, 9),
		Vector2i(10, 10),
		Vector2i(11, 10),
		Vector2i(10, 11),
		Vector2i(11, 11),
		Vector2i(10, 12),
		Vector2i(9, 10),
	]

	_paint(world, field.slice(0, field.size() - 1), WorldGrid.Terrain.SOIL)
	check(
		"seven tilled tiles are not eight",
		Placement.can_place(world, "farm", hut) == Placement.Reason.MISSING_SOIL,
		Placement.reason_text(Placement.can_place(world, "farm", hut))
	)

	_paint(world, [field[-1]], WorldGrid.Terrain.SOIL)
	check(
		"eight tilled tiles in reach make a farm site",
		Placement.can_place(world, "farm", hut) == Placement.Reason.OK
	)
	check(
		"the farm itself wants grass, so it never sits on its own field",
		Placement.can_place(world, "farm", Vector2i(11, 11)) == Placement.Reason.TERRAIN
	)


func _test_ghost_and_commit() -> void:
	var scene: PackedScene = load("res://scenes/levels/main.tscn")
	var main = scene.instantiate()
	(main.get_node("Camera2D") as CameraController).edge_margin = 0.0
	root.add_child(main)
	await process_frame

	var world: WorldGrid = main.world
	var camp_tile := Vector2i.ONE * (WorldGenerator.MAP_SIZE / 2)

	check(
		"the camp is founded in the clearing",
		world.buildings.size() == 1 and world.building_at(camp_tile) >= 0,
		"%d buildings" % world.buildings.size()
	)

	main.begin_placement("house")
	check(
		"arming a building shows the pale preview",
		main.placement_id == "house" and main.ghost.visible
	)
	check(
		"the room is picked off the roster, not the mouse",
		main.ghost.get("_def").get("name", "") == "House",
		str(main.ghost.get("_def"))
	)

	main.set_pointer(Vector2(30.5, 31.5) * WorldRenderer.TILE_SIZE)
	check(
		"the preview snaps to the tile under the pointer",
		main.ghost.tile == Vector2i(30, 31)
		and main.ghost.footprint_rect().size == Vector2(2, 2) * WorldRenderer.TILE_SIZE
		and main.ghost.footprint_rect().position
		== Vector2(30, 31) * WorldRenderer.TILE_SIZE,
		"%s at %s" % [main.ghost.tile, main.ghost.footprint_rect()]
	)
	check(
		"clear ground previews as buildable",
		main.ghost.reason == Placement.Reason.OK,
		Placement.reason_text(main.ghost.reason)
	)

	var id: int = main.try_commit()

	check(
		"committing places the building in the world",
		id >= 0
		and world.buildings.size() == 2
		and world.building_at(main.ghost.tile) == id,
		"id %d, %d buildings" % [id, world.buildings.size()]
	)
	check(
		"the placed building gets its sprite without a map rebuild",
		main.world_renderer.object_nodes.has(id)
		and main.world_renderer.object_nodes[id] is Sprite2D
	)

	# A building flattens the cover it stands on, so tufts never poke through.
	var cover_tile := Vector2i(34, 31)
	var cover_id: int = world.add_object({
		"type": "tuft",
		"name": "tall_grass_tuft",
		"x": cover_tile.x,
		"y": cover_tile.y,
	})
	main.world_renderer.spawn_object(cover_id)

	main.begin_placement("camp")
	main.set_pointer(
		Vector2(cover_tile.x + 0.5, cover_tile.y + 0.5) * WorldRenderer.TILE_SIZE
	)
	check(
		"a tuft does not stop a building",
		main.ghost.reason == Placement.Reason.OK,
		Placement.reason_text(main.ghost.reason)
	)

	main.try_commit()
	check(
		"the building flattens the cover it stands on",
		not world.objects_by_id.has(cover_id)
		and not main.world_renderer.object_nodes.has(cover_id),
		str(world.objects_by_id.has(cover_id))
	)

	# Back to the house for the checks below.
	main.begin_placement("house")
	check(
		"placement stays armed for the next building",
		main.placement_id == "house" and main.ghost.visible
	)

	main.set_pointer(Vector2(-8.0, -8.0))
	check(
		"outside the map the preview goes red and refuses",
		main.ghost.reason == Placement.Reason.OUT_OF_BOUNDS
		and Placement.reason_text(main.ghost.reason) != ""
		and main.try_commit() == -1
	)

	var before: Vector2 = main.camera.position
	main.camera.pan_by(Vector2(0.0, 64.0))
	check(
		"middle-drag pan moves the camera against the drag",
		not main.camera.position.is_equal_approx(before),
		"%s -> %s" % [before, main.camera.position]
	)

	main.cancel_placement()
	check(
		"cancelling hides the preview and disarms placement",
		not main.ghost.visible and main.placement_id == "" and main.try_commit() == -1
	)

	main.cycle_placement()
	var first: String = main.placement_id
	main.cycle_placement()
	check(
		"one key walks the roster in order",
		first == BuildingDefs.ORDER[0] and main.placement_id == BuildingDefs.ORDER[1],
		"%s then %s" % [first, main.placement_id]
	)

	main.queue_free()
	finish()
