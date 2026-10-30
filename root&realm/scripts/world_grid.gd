class_name WorldGrid
extends RefCounted

## The generated world: one terrain byte and one ground-variant byte per tile.
##
## Grass is the base layer; soil and water are painted on top of it, which is the
## only direction the kit's corner atlases can blend (the "upper" terrain covers
## the "lower" grass).

enum Terrain {
	GRASS,
	SOIL,
	WATER
}

var size: Vector2i
var terrain: PackedByteArray
# Which of the 16 base grass tiles a cell uses. Generated with the world so the
# renderer never rolls its own dice and a rebuild is identical.
var ground_variant: PackedByteArray
var objects: Array[Dictionary] = []
# Objects are addressed by id, not by their index in `objects`: deleting one
# must not renumber the rest. Every object dict created through add_object()
# carries its own "id". `objects_by_tile` maps a tile to the ids anchored in it,
# which is the lookup for picking and, later, for build placement.
var objects_by_id := {}
var objects_by_tile := {}
var next_object_id := 0
# Buildings are objects too (id, tile, type "building"), but a footprint covers
# tiles its anchor does not, so the whole area is indexed for clearance.
var buildings: Array[int] = []
var buildings_by_tile := {}
# Field plots are planted as whole units: a disc of tilled soil with a few
# tufts. Each of their tufts carries the plot's index in "patch".
var patches: Array[Dictionary] = []


func _init(map_size: Vector2i) -> void:
	size = map_size
	terrain.resize(size.x * size.y)
	terrain.fill(Terrain.GRASS)
	ground_variant.resize(size.x * size.y)
	ground_variant.fill(0)


func turn_position(pos: Vector2, clockwise := true) -> Vector2:
	if clockwise:
		return Vector2(size.x - 1 - pos.y, pos.x)
	else:
		return Vector2(pos.y, size.y - 1 - pos.x)


func rotate_quarter_turn(clockwise := true) -> void:
	## Turns the whole map a quarter turn: terrain, ground variants, object
	## tiles, their art offsets and building footprints. Ids survive, so a
	## building stays the same building, and four turns return the original map.
	##
	## This is a transform of the *map*, not of the view: sprites keep their
	## orientation, which is what lets something hidden behind a canopy end up
	## beside it. The world is square, so its size does not change.
	if size.x != size.y:
		push_error("WorldGrid: only a square map can be turned")
		return

	var width := size.x
	var turned := PackedByteArray()
	var turned_variant := PackedByteArray()
	turned.resize(terrain.size())
	turned_variant.resize(ground_variant.size())

	for y in range(size.y):
		for x in range(size.x):
			var from := y * width + x
			var to := (
				x * width + (width - 1 - y)
				if clockwise
				else (width - 1 - x) * width + y
			)
			turned[to] = terrain[from]
			turned_variant[to] = ground_variant[from]

	terrain = turned
	ground_variant = turned_variant

	for data in objects:
		_turn_object(data, clockwise)

	for patch in patches:
		var center := _turned_tile(Vector2i(patch["x"], patch["y"]), clockwise)
		patch["x"] = center.x
		patch["y"] = center.y

	_reindex()


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size.x and y < size.y


func set_terrain(x: int, y: int, value: Terrain) -> void:
	if not in_bounds(x, y):
		return

	terrain[y * size.x + x] = value


func get_terrain(x: int, y: int) -> Terrain:
	if not in_bounds(x, y):
		return Terrain.GRASS

	return terrain[y * size.x + x]


func set_ground_variant(x: int, y: int, value: int) -> void:
	if not in_bounds(x, y):
		return

	ground_variant[y * size.x + x] = value


func get_ground_variant(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return 0

	return ground_variant[y * size.x + x]


func is_water(x: int, y: int) -> bool:
	return get_terrain(x, y) == Terrain.WATER


func add_object(data: Dictionary) -> int:
	var id := next_object_id
	next_object_id += 1
	data["id"] = id
	objects.append(data)
	objects_by_id[id] = data

	var tile := Vector2i(data["x"], data["y"])
	if not objects_by_tile.has(tile):
		var ids: Array[int] = []
		objects_by_tile[tile] = ids
	objects_by_tile[tile].append(id)

	return id


func add_building(building_id: String, tile: Vector2i, footprint: Vector2i) -> int:
	## Adds a building and claims each footprint tile, so nothing else can be
	## placed on ground it covers.
	var id := add_object({
		"type": "building",
		"name": building_id,
		"x": tile.x,
		"y": tile.y,
		"size": footprint,
	})
	buildings.append(id)

	for y in range(footprint.y):
		for x in range(footprint.x):
			buildings_by_tile[tile + Vector2i(x, y)] = id

	return id


func building_at(tile: Vector2i) -> int:
	## The building covering a tile, or -1 for open ground.
	return buildings_by_tile.get(tile, -1)


func remove_object(id: int) -> Dictionary:
	## Drops the object and returns it, or returns an empty dict if it is gone.
	var data: Dictionary = objects_by_id.get(id, {})

	if data.is_empty():
		return {}

	if data.get("type", "") == "building":
		_release_building(data)

	var tile := Vector2i(data["x"], data["y"])
	var ids: Array = objects_by_tile.get(tile, [])
	ids.erase(id)
	if ids.is_empty():
		objects_by_tile.erase(tile)

	objects_by_id.erase(id)
	var index := objects.find(data)
	if index >= 0:
		objects.remove_at(index)

	return data


func _turned_tile(tile: Vector2i, clockwise: bool) -> Vector2i:
	if clockwise:
		return Vector2i(size.x - 1 - tile.y, tile.x)

	return Vector2i(tile.y, size.y - 1 - tile.x)


func _turn_object(data: Dictionary, clockwise: bool) -> void:
	var tile := Vector2i(data["x"], data["y"])

	if data.get("type", "") == "building":
		# A footprint does not turn about its top-left: the turned anchor is the
		# corner the whole rectangle lands on, and its sides swap.
		var footprint: Vector2i = data.get("size", Vector2i.ONE)
		var anchor := (
			Vector2i(size.x - tile.y - footprint.y, tile.x)
			if clockwise
			else Vector2i(tile.y, size.y - tile.x - footprint.x)
		)

		data["size"] = Vector2i(footprint.y, footprint.x)
		data["x"] = anchor.x
		data["y"] = anchor.y
		return

	if data.has("offset"):
		# The nudge is screen-space, so it turns with everything else.
		var offset: Vector2 = data["offset"]
		data["offset"] = (
			Vector2(-offset.y, offset.x) if clockwise else Vector2(offset.y, -offset.x)
		)

	var turned := _turned_tile(tile, clockwise)
	data["x"] = turned.x
	data["y"] = turned.y


func _reindex() -> void:
	## Rebuilds the tile lookups after the objects moved: erasing each old tile
	## would be the same work with more ways to leave a stale entry behind.
	objects_by_tile.clear()
	buildings_by_tile.clear()

	for data in objects:
		var tile := Vector2i(data["x"], data["y"])

		if not objects_by_tile.has(tile):
			var ids: Array[int] = []
			objects_by_tile[tile] = ids
		objects_by_tile[tile].append(data["id"])

		if data.get("type", "") == "building":
			var footprint: Vector2i = data.get("size", Vector2i.ONE)

			for y in range(footprint.y):
				for x in range(footprint.x):
					buildings_by_tile[tile + Vector2i(x, y)] = data["id"]


func _release_building(data: Dictionary) -> void:
	# Drops a building's claim on every tile, not just the anchor it is indexed
	# under, or the footprint would keep blocking placements after demolition.
	var size: Vector2i = data.get("size", Vector2i.ONE)
	var anchor := Vector2i(data["x"], data["y"])

	for y in range(size.y):
		for x in range(size.x):
			buildings_by_tile.erase(anchor + Vector2i(x, y))

	buildings.erase(data["id"])


func remove_objects_from(first_id: int) -> void:
	## Rolls back everything added at or after first_id, e.g. a half-planted
	## field. Ids stay monotonic, so the rollback does not make later ids reuse
	## numbers.
	while not objects.is_empty() and objects[-1]["id"] >= first_id:
		remove_object(objects[-1]["id"])
