extends "res://tests/_test_case.gd"

# Determinism and the object identity model: pure data, no scene.


func run() -> void:
	print("world generation")
	var started := Time.get_ticks_msec()
	var first := WorldGenerator.new().generate_world(WORLD_SEED)
	var second := WorldGenerator.new().generate_world(WORLD_SEED)
	var other := WorldGenerator.new().generate_world(WORLD_SEED + 1)

	check("same seed reproduces the terrain", first.terrain == second.terrain)
	check("same seed reproduces the grass variants", first.ground_variant == second.ground_variant)
	check("same seed reproduces the objects", first.objects == second.objects)
	check("a different seed moves the terrain", first.terrain != other.terrain)
	check("a different seed moves the trees and props", first.objects != other.objects)
	print("  info  three worlds generated in %d ms" % (Time.get_ticks_msec() - started))

	print("object identity")
	var world := WorldGenerator.new().generate_world(WORLD_SEED)
	var seen := {}
	var ids_unique := true
	var ids_address_data := true
	var tile_index_ok := true

	for i in range(world.objects.size()):
		var obj: Dictionary = world.objects[i]
		var id: int = obj["id"]

		if seen.has(id):
			ids_unique = false
		seen[id] = true

		if world.objects_by_id.get(id) != obj:
			ids_address_data = false

		var tile := Vector2i(obj["x"], obj["y"])
		if not world.objects_by_tile.get(tile, []).has(id):
			tile_index_ok = false

	check("every object has a unique id", ids_unique and seen.size() == world.objects.size())
	check("ids address the same dict as the array", ids_address_data)
	check("the tile index lists every object", tile_index_ok)

	var removed: Dictionary = world.remove_object(world.objects[0]["id"])
	var removed_id: int = removed["id"]
	check(
		"removing an object drops it from the data and both indexes",
		removed_id == 0
		and not world.objects_by_id.has(removed_id)
		and not world.objects.has(removed)
		and not world.objects_by_tile.get(
			Vector2i(removed["x"], removed["y"]), []
		).has(removed_id)
	)
	check("removing an object twice is a no-op", world.remove_object(removed_id).is_empty())

	var first_id := world.next_object_id
	var added := world.add_object({"type": "prop", "name": "mossy_rock", "x": 1, "y": 1})
	check(
		"a new object gets a fresh id and is indexed",
		added == first_id
		and world.next_object_id == first_id + 1
		and world.objects_by_tile[Vector2i(1, 1)].has(added)
	)

	var rolled_back := world.add_object({"type": "prop", "name": "mossy_rock", "x": 1, "y": 1})
	world.remove_objects_from(first_id)
	check(
		"a rollback drops the objects added at or after the marker",
		rolled_back != added
		and not world.objects_by_id.has(added)
		and not world.objects_by_id.has(rolled_back)
	)

	finish()
