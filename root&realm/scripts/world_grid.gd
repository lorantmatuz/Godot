extends RefCounted
class_name WorldGrid

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
# Field plots are planted as whole units: a disc of tilled soil with a few
# tufts. Each of their tufts carries the plot's index in "patch".
var patches: Array[Dictionary] = []


func _init(map_size: Vector2i) -> void:
	size = map_size
	terrain.resize(size.x * size.y)
	terrain.fill(Terrain.GRASS)
	ground_variant.resize(size.x * size.y)
	ground_variant.fill(0)


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
