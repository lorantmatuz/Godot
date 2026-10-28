extends RefCounted
class_name WorldGenerator

const MAP_SIZE := 64
const CLEARING_RADIUS := 4.0
const OBJECT_CLEARING_RADIUS := 5.0
const START_RESOURCE_RADIUS := 12.0

const WATER_LEVEL := -0.30
const ROCK_LEVEL := 0.42

const TREE_DENSITY_FOREST := 0.2
const TREE_DENSITY_GRASS := 0.012
const ROCK_DENSITY := 0.20

const FOREST_CLEARING_SIZE := 2.0
const ROCK_CLEARING_SIZE := 2.0
const STARTING_GROVE_TREES := 7
const STARTING_OUTCROP_STONES := 5

var rng := RandomNumberGenerator.new()
var elevation := FastNoiseLite.new()
var moisture := FastNoiseLite.new()


func generate_world(seed_value: int) -> WorldGrid:
	rng.seed = seed_value
	_setup_noise(seed_value)

	var world := WorldGrid.new(Vector2i(MAP_SIZE, MAP_SIZE))

	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			world.set_terrain(x, y, _terrain_at(x, y))

	_flatten_starting_clearing(world)
	_place_guaranteed_terrain(world)
	_scatter_objects(world)
	_place_guaranteed_objects(world)

	return world


func _setup_noise(seed_value: int) -> void:
	elevation.seed = seed_value
	elevation.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elevation.frequency = 0.035
	elevation.fractal_octaves = 3
	elevation.fractal_gain = 0.5

	moisture.seed = seed_value + 1
	moisture.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moisture.frequency = 0.05
	moisture.fractal_octaves = 2


func _terrain_at(x: int, y: int) -> WorldGrid.Terrain:
	var height := elevation.get_noise_2d(x, y)

	if height < WATER_LEVEL:
		return WorldGrid.Terrain.WATER

	if height > ROCK_LEVEL:
		return WorldGrid.Terrain.ROCKY

	if moisture.get_noise_2d(x, y) > 0.0:
		return WorldGrid.Terrain.FOREST_FLOOR

	return WorldGrid.Terrain.GRASS


func _flatten_starting_clearing(world: WorldGrid) -> void:
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			if _distance_to_center(x, y) <= CLEARING_RADIUS:
				world.set_terrain(x, y, WorldGrid.Terrain.GRASS)


func _place_guaranteed_terrain(world: WorldGrid) -> void:
	var center := _map_center()

	# A grove and an outcrop close enough to reach on foot before any expansion.
	_force_patch(world, center + Vector2i(8, 2), FOREST_CLEARING_SIZE, WorldGrid.Terrain.FOREST_FLOOR)
	_force_patch(world, center + Vector2i(-7, -4), ROCK_CLEARING_SIZE, WorldGrid.Terrain.ROCKY)


func _force_patch(world: WorldGrid, center: Vector2i, radius: float, value: WorldGrid.Terrain) -> void:
	var reach := ceili(radius)

	for y in range(center.y - reach, center.y + reach + 1):
		for x in range(center.x - reach, center.x + reach + 1):
			if Vector2(x - center.x, y - center.y).length() <= radius:
				world.set_terrain(x, y, value)


func _scatter_objects(world: WorldGrid) -> void:
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			if _distance_to_center(x, y) <= OBJECT_CLEARING_RADIUS:
				continue

			match world.get_terrain(x, y):
				WorldGrid.Terrain.FOREST_FLOOR:
					if rng.randf() < TREE_DENSITY_FOREST:
						_add_tree(world, x, y)
				WorldGrid.Terrain.GRASS:
					if rng.randf() < TREE_DENSITY_GRASS:
						_add_tree(world, x, y)
				WorldGrid.Terrain.ROCKY:
					if rng.randf() < ROCK_DENSITY:
						_add_stone(world, x, y)


func _place_guaranteed_objects(world: WorldGrid) -> void:
	var center := _map_center()

	_plant_cluster(
		world,
		center + Vector2i(8, 2),
		FOREST_CLEARING_SIZE,
		"tree",
		STARTING_GROVE_TREES
	)
	_plant_cluster(
		world,
		center + Vector2i(-7, -4),
		ROCK_CLEARING_SIZE,
		"stone",
		STARTING_OUTCROP_STONES
	)


func _plant_cluster(
	world: WorldGrid,
	center: Vector2i,
	radius: float,
	type: String,
	amount: int
) -> void:
	var reach := ceili(radius)
	var candidates: Array[Vector2i] = []

	for y in range(center.y - reach, center.y + reach + 1):
		for x in range(center.x - reach, center.x + reach + 1):
			if not world.in_bounds(x, y):
				continue
			if Vector2(x - center.x, y - center.y).length() > radius:
				continue
			if _has_object(world, x, y):
				continue
			candidates.append(Vector2i(x, y))

	_shuffle_tiles(candidates)

	for tile in candidates.slice(0, amount):
		if type == "tree":
			_add_tree(world, tile.x, tile.y)
		else:
			_add_stone(world, tile.x, tile.y)


func _shuffle_tiles(tiles: Array[Vector2i]) -> void:
	# Array.shuffle() uses the global RNG, which is not seeded with our world seed.
	for i in range(tiles.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := tiles[i]
		tiles[i] = tiles[j]
		tiles[j] = swap


func _has_object(world: WorldGrid, x: int, y: int) -> bool:
	for obj in world.objects:
		if obj["x"] == x and obj["y"] == y:
			return true

	return false


func _add_tree(world: WorldGrid, x: int, y: int) -> void:
	world.objects.append({
		"type": "tree",
		"x": x,
		"y": y,
		"stage": _random_tree_stage()
	})


func _add_stone(world: WorldGrid, x: int, y: int) -> void:
	world.objects.append({
		"type": "stone",
		"x": x,
		"y": y
	})


func _random_tree_stage() -> int:
	var roll := rng.randf()

	if roll < 0.15:
		return TreeEntity.TreeStage.SEEDLING

	if roll < 0.40:
		return TreeEntity.TreeStage.YOUNG

	return TreeEntity.TreeStage.MATURE


func _map_center() -> Vector2i:
	return Vector2i(MAP_SIZE / 2, MAP_SIZE / 2)


func _distance_to_center(x: int, y: int) -> float:
	var center := _map_center()
	return Vector2(x - center.x, y - center.y).length()
