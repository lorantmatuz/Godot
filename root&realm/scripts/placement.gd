class_name Placement
extends RefCounted

## The placement rule: can this building stand on this tile, and if not, why.
##
## Everything here is argument-driven and reads only `WorldGrid` data, so the
## rules can be tested headlessly, and the ghost, a future build menu and the
## inspector all get the same answer.

enum Reason {
	OK,
	UNKNOWN,
	OUT_OF_BOUNDS,
	TERRAIN,
	OCCUPIED,
	MISSING_TREES,
	MISSING_SOIL,
}

# Ground cover is flattened by a building rather than vetoing it. The kit
# scatters tufts, flowers and mushrooms across the meadow, and refusing every
# tile with a blade of grass on it made open ground look unusable. Trees,
# bushes, rocks and other buildings still block.
const GROUND_COVER := [
	"tall_grass_tuft",
	"blue_flowers_patch",
	"yellow_flowers_patch",
	"red_mushrooms",
]

const REASON_TEXT := {
	Reason.OK: "",
	Reason.UNKNOWN: "unknown building",
	Reason.OUT_OF_BOUNDS: "outside the map",
	Reason.TERRAIN: "can't stand on this ground",
	Reason.OCCUPIED: "something is in the way",
	Reason.MISSING_TREES: "no mature trees in reach",
	Reason.MISSING_SOIL: "no tilled soil in reach",
}


static func footprint_tiles(id: String, tile: Vector2i) -> Array[Vector2i]:
	## Every tile the building would stand on, anchored at its top-left. An
	## unknown id covers nothing rather than pretending to be a 1x1.
	var def := BuildingDefs.get_def(id)
	var tiles: Array[Vector2i] = []

	if def.is_empty():
		return tiles

	var size: Vector2i = def.get("size", Vector2i.ONE)

	for y in range(size.y):
		for x in range(size.x):
			tiles.append(tile + Vector2i(x, y))

	return tiles


static func can_place(world: WorldGrid, id: String, tile: Vector2i) -> Reason:
	## The first thing wrong, not a bool: the ghost has to say why it is red.
	var def := BuildingDefs.get_def(id)

	if def.is_empty():
		return Reason.UNKNOWN

	var allowed: Array = def.get("terrain", [])
	var cells := footprint_tiles(id, tile)

	for cell in cells:
		if not world.in_bounds(cell.x, cell.y):
			return Reason.OUT_OF_BOUNDS

	for cell in cells:
		if not allowed.has(world.get_terrain(cell.x, cell.y)):
			return Reason.TERRAIN

		# A building blocks its whole footprint, so every tile is indexed; the
		# objects standing there block it unless they are only ground cover.
		if world.buildings_by_tile.has(cell):
			return Reason.OCCUPIED

		for object_id in world.objects_by_tile.get(cell, []):
			if blocks_building(world.objects_by_id.get(object_id, {})):
				return Reason.OCCUPIED

	return _site_reason(world, def, tile)


static func blocks_building(data: Dictionary) -> bool:
	## Whether an object vetoes a building on its tile: everything except the
	## cover a building would simply stand on top of.
	if data.is_empty():
		return false

	return data.get("type", "") != "tuft" and not GROUND_COVER.has(data.get("name", ""))


static func reason_text(reason: Reason) -> String:
	## A short line for the ghost's label; empty when the tiles are usable.
	return REASON_TEXT.get(reason, "")


static func _site_reason(world: WorldGrid, def: Dictionary, tile: Vector2i) -> Reason:
	## Land already covered by the footprint does not count towards its own
	## requirement, and neither does anything outside the radius.
	var requirement: Dictionary = def.get("requirement", {})

	if requirement.is_empty():
		return Reason.OK

	var size: Vector2i = def.get("size", Vector2i.ONE)
	var centre := Vector2(tile) + Vector2(size) * 0.5
	var kind: String = requirement["kind"]
	var radius: float = requirement["radius"]
	var wanted: int = requirement["count"]
	var found := 0

	for y in range(floori(centre.y - radius), ceili(centre.y + radius) + 1):
		for x in range(floori(centre.x - radius), ceili(centre.x + radius) + 1):
			if found >= wanted:
				break
			if not world.in_bounds(x, y):
				continue
			if Vector2(x + 0.5, y + 0.5).distance_to(centre) > radius:
				continue

			found += _count_at(world, kind, Vector2i(x, y))

	if found >= wanted:
		return Reason.OK

	return Reason.MISSING_TREES if kind == "trees" else Reason.MISSING_SOIL


static func _count_at(world: WorldGrid, kind: String, tile: Vector2i) -> int:
	## How much of `kind` one tile contributes: soil is one, trees are the mature
	## ones anchored there (seedlings and young trees cannot be harvested yet).
	if kind == "soil":
		return 1 if world.get_terrain(tile.x, tile.y) == WorldGrid.Terrain.SOIL else 0

	var found := 0

	for object_id in world.objects_by_tile.get(tile, []):
		var data: Dictionary = world.objects_by_id.get(object_id, {})

		if (
			data.get("type", "") == "tree"
			and data.get("stage", -1) == TreeEntity.TreeStage.MATURE
		):
			found += 1

	return found
