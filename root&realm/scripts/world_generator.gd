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

# Resource patches are planted as one unit: a ragged blob of tiles all covered
# with the same resource, so it reads as a meadow or a quarry a farmer or
# quarryman could work, instead of scattered singles. Trees stay on their own.
const MEADOW_CHANCE := 0.05
const QUARRY_CHANCE := 0.16
# Meadow radius, in tiles. Its rim thins out, so the edge looks grown.
const MEADOW_RADIUS_MIN := 2.6
const MEADOW_RADIUS_MAX := 4.2
const PATCH_GAP := 8.0
# Share of the radius that stays fully planted; the rest of the rim thins out
# so the patch edge looks grown rather than stamped.
const PATCH_EDGE_FALLOFF := 0.45
const PATCH_TUFTS_PER_TILE := 5.0

# A quarry is one packed field of loose stones, never a grid of separate piles:
# stones sit on a jittered lattice closer than their own width, so each stone
# touches its neighbours and the field reads as continuous rubble.
const QUARRY_MIN_STONES := 10
const QUARRY_MAX_STONES := 100
# Tiles between lattice points. A rock sprite is 31 px cut down to 23 px by the
# rock scene, so the packed pitch has to stay under ~0.35 tiles.
const QUARRY_STONE_PITCH := 0.3
const QUARRY_STONE_JITTER := 0.05
# Lattice points gathered per wanted stone, so the field fills its disc instead
# of thinning when a few points fall on bare ground.
const QUARRY_PACK := 1.35

# A patch that ends up thinner than this is dropped entirely, so a meadow or
# quarry is never just a few stray sprites next to each other.
const PATCH_MIN_TUFTS := 30

# Must match the sprite lists in WorldRenderer.
const TUFT_VARIANTS := 4
const ROCK_VARIANTS := 5

const FOREST_CLEARING_SIZE := 2.0
const ROCK_CLEARING_SIZE := 3.0
const MEADOW_CLEARING_SIZE := 2.8
const STARTING_GROVE_TREES := 7
const STARTING_PATCH_RADIUS := 3.0

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
	_scatter_trees(world)
	_scatter_patches(world)
	_plant_starting_patches(world)

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

	# One patch of each resource ground close enough to reach on foot before
	# any expansion.
	_force_patch(world, center + Vector2i(9, 2), FOREST_CLEARING_SIZE, WorldGrid.Terrain.FOREST_FLOOR)
	_force_patch(world, center + Vector2i(-8, -5), ROCK_CLEARING_SIZE, WorldGrid.Terrain.ROCKY)
	_force_patch(world, center + Vector2i(4, -10), MEADOW_CLEARING_SIZE, WorldGrid.Terrain.GRASS)


func _force_patch(world: WorldGrid, center: Vector2i, radius: float, value: WorldGrid.Terrain) -> void:
	var reach := ceili(radius)

	for y in range(center.y - reach, center.y + reach + 1):
		for x in range(center.x - reach, center.x + reach + 1):
			if Vector2(x - center.x, y - center.y).length() <= radius:
				world.set_terrain(x, y, value)


func _scatter_trees(world: WorldGrid) -> void:
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


func _meadow_kind() -> Dictionary:
	return {
		"terrain": WorldGrid.Terrain.GRASS,
		"patch": "meadow",
		"chance": MEADOW_CHANCE,
		"radius_min": MEADOW_RADIUS_MIN,
		"radius_max": MEADOW_RADIUS_MAX,
		"min_objects": PATCH_MIN_TUFTS
	}


func _quarry_kind() -> Dictionary:
	return {
		"terrain": WorldGrid.Terrain.ROCKY,
		"patch": "quarry",
		"chance": QUARRY_CHANCE,
		"min_objects": QUARRY_MIN_STONES
	}


func _scatter_patches(world: WorldGrid) -> void:
	for kind in [_meadow_kind(), _quarry_kind()]:
		_scatter_patches_of(world, kind)


func _scatter_patches_of(world: WorldGrid, kind: Dictionary) -> void:
	var centers: Array[Vector2i] = []

	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			if world.get_terrain(x, y) != kind["terrain"]:
				continue
			if _distance_to_center(x, y) <= OBJECT_CLEARING_RADIUS:
				continue
			if rng.randf() >= float(kind["chance"]):
				continue

			var center := Vector2i(x, y)
			if _too_close(centers, center):
				continue

			centers.append(center)
			_plant_patch(world, center, kind)


func _too_close(centers: Array[Vector2i], center: Vector2i) -> bool:
	# Patches are whole set pieces, so they keep a gap instead of growing into
	# one another.
	for other in centers:
		if Vector2(other - center).length() < PATCH_GAP:
			return true

	return false


func _plant_patch(
	world: WorldGrid,
	center: Vector2i,
	kind: Dictionary,
	radius: float = -1.0
) -> void:
	var index := world.patches.size()
	var first_object := world.objects.size()

	if kind["patch"] == "quarry":
		radius = _plant_quarry(world, center, index)
	else:
		if radius < 0.0:
			radius = rng.randf_range(float(kind["radius_min"]), float(kind["radius_max"]))
		_plant_meadow(world, center, index, radius)

	var planted := world.objects.size() - first_object

	if radius <= 0.0 or planted < int(kind["min_objects"]):
		# Not enough ground to plant on: drop the whole patch, not its pieces.
		world.objects.resize(first_object)
		return

	world.patches.append({
		"type": kind["patch"],
		"x": center.x,
		"y": center.y,
		"radius": radius
	})


func _patch_cover(distance: float, radius: float) -> float:
	var full := radius * (1.0 - PATCH_EDGE_FALLOFF)

	return clampf((radius - distance) / maxf(radius - full, 0.001), 0.0, 1.0)


func _plant_meadow(world: WorldGrid, center: Vector2i, patch: int, radius: float) -> void:
	var reach := ceili(radius)

	for y in range(center.y - reach, center.y + reach + 1):
		for x in range(center.x - reach, center.x + reach + 1):
			if not world.in_bounds(x, y):
				continue
			if world.get_terrain(x, y) != WorldGrid.Terrain.GRASS:
				continue
			# The camp clearing stays open, even where a patch would reach it.
			if _distance_to_center(x, y) <= OBJECT_CLEARING_RADIUS:
				continue

			var distance := Vector2(x - center.x, y - center.y).length()
			if distance > radius:
				continue

			_plant_tufts(world, x, y, patch, _patch_cover(distance, radius))


func _plant_tufts(world: WorldGrid, x: int, y: int, patch: int, cover: float) -> void:
	var amount := roundi(PATCH_TUFTS_PER_TILE * cover * rng.randf_range(0.6, 1.2))

	for i in range(amount):
		world.objects.append({
			"type": "tuft",
			"x": x,
			"y": y,
			"offset": _random_offset(),
			"variant": rng.randi_range(0, TUFT_VARIANTS - 1),
			"flip": rng.randf() < 0.5,
			"patch": patch
		})


func _plant_quarry(world: WorldGrid, center: Vector2i, patch: int) -> float:
	# Pick the number of stones first, then gather lattice points over a disc
	# large enough to hold them. Keeping the points nearest the centre and
	# discarding the rest leaves one solid field: no gaps inside, and a ragged
	# rim instead of an even grid boundary.
	var target := rng.randi_range(QUARRY_MIN_STONES, QUARRY_MAX_STONES)
	var search := QUARRY_STONE_PITCH * sqrt(float(target) * QUARRY_PACK / PI)
	var extent := ceili(search / QUARRY_STONE_PITCH) + 1
	var center_f := Vector2(center)
	var ranked: Array[Vector3] = []

	for iy in range(-extent, extent + 1):
		for ix in range(-extent, extent + 1):
			var spot := center_f + Vector2(ix, iy) * QUARRY_STONE_PITCH
			spot += Vector2(
				rng.randf_range(-QUARRY_STONE_JITTER, QUARRY_STONE_JITTER),
				rng.randf_range(-QUARRY_STONE_JITTER, QUARRY_STONE_JITTER)
			)

			var distance := spot.distance_to(center_f)
			if distance > search:
				continue

			var tile := Vector2i(spot.floor())

			if not world.in_bounds(tile.x, tile.y):
				continue
			if world.get_terrain(tile.x, tile.y) != WorldGrid.Terrain.ROCKY:
				continue
			# The camp clearing stays open, even where a field would reach it.
			if _distance_to_center(tile.x, tile.y) <= OBJECT_CLEARING_RADIUS:
				continue

			# The rank wobbles the rim, so the field does not end in a clean circle.
			ranked.append(Vector3(spot.x, spot.y, distance + rng.randf_range(-0.2, 0.2)))

	if ranked.size() < QUARRY_MIN_STONES:
		return 0.0

	ranked.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z < b.z)

	var furthest := 0.0
	var count := mini(ranked.size(), target)

	for i in range(count):
		var spot := Vector2(ranked[i].x, ranked[i].y)
		var tile := Vector2i(spot.floor())

		furthest = maxf(furthest, spot.distance_to(center_f))
		world.objects.append({
			"type": "stone",
			"x": tile.x,
			"y": tile.y,
			"offset": spot - (Vector2(tile) + Vector2.ONE * 0.5),
			"variant": rng.randi_range(0, ROCK_VARIANTS - 1),
			"flip": rng.randf() < 0.5,
			"patch": patch
		})

	return maxf(furthest + 0.5, 0.5)


func _random_offset() -> Vector2:
	# Offsets are a share of the tile, so the data stays independent of the
	# renderer's pixel size. Values under 0.5 keep an object in its own tile.
	return Vector2(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45))


func _plant_starting_patches(world: WorldGrid) -> void:
	var center := _map_center()

	_plant_tree_cluster(
		world,
		center + Vector2i(9, 2),
		FOREST_CLEARING_SIZE,
		STARTING_GROVE_TREES
	)

	_plant_patch(world, center + Vector2i(4, -10), _meadow_kind(), STARTING_PATCH_RADIUS)
	_plant_patch(world, center + Vector2i(-8, -5), _quarry_kind())


func _plant_tree_cluster(
	world: WorldGrid,
	center: Vector2i,
	radius: float,
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
		_add_tree(world, tile.x, tile.y)


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
