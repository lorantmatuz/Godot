extends RefCounted
class_name WorldGrid

enum Terrain {
	WATER,
	GRASS,
	FOREST_FLOOR,
	ROCKY
}

var size: Vector2i
var terrain: PackedByteArray
var objects: Array[Dictionary] = []


func _init(map_size: Vector2i) -> void:
	size = map_size
	terrain.resize(size.x * size.y)
	terrain.fill(Terrain.GRASS)


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size.x and y < size.y


func set_terrain(x: int, y: int, value: Terrain) -> void:
	if not in_bounds(x, y):
		return

	terrain[y * size.x + x] = value


func get_terrain(x: int, y: int) -> Terrain:
	if not in_bounds(x, y):
		return Terrain.WATER

	return terrain[y * size.x + x]
