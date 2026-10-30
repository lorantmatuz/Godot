class_name WorldGenerator
extends RefCounted

## Procedural world for the Cozy World Kit migration.
##
## Grass is the base; soil (camp, trails, erosion, field plots) and water (ponds)
## are painted on top. Every water tile gets a one-tile grass bank: the kit has no
## soil ↔ water corner set, so those two terrains must never touch.

const MAP_SIZE := 64
const CLEARING_RADIUS := 4.0
const OBJECT_CLEARING_RADIUS := 5.5
const START_RESOURCE_RADIUS := 12.0

# The dirt-patch fills (atlas columns 5 and 13) are mostly baked soil; on this
# map dirt is a real terrain, so they would read as fake soil on the meadow.
const GRASS_VARIANT_POOL: Array[int] = [0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 14, 15]

# The blend atlases are fully opaque, so a soil or water tile overwrites whole
# 16x16 quadrants of the grass fill in the eight tiles around it. Variant 0 is
# the atlases' own grass tile pixel for pixel; every other fill has jitter or
# baked decor that would be sliced and show a seam along the quadrant edge.
const BLEND_EDGE_VARIANT := 0

# Trees stay on their own; fields are planted as whole units.
const TREE_DENSITY_MIN := 0.01
const TREE_DENSITY_MAX := 0.22
# No second tree within this Chebyshev distance, so 64 px canopies keep a gap.
const TREE_SPACING := 1
const MATURE_SPECIES := ["oak", "pine", "cherry", "willow"]

const POND_COUNT_MIN := 1
const POND_COUNT_MAX := 3
const POND_RADIUS_MIN := 2.6
const POND_RADIUS_MAX := 5.0
# Ponds stay away from the starting camp, and from each other.
const POND_FROM_START := 13.0
const POND_GAP := 3.0
const POND_EDGE_WOBBLE := 0.9

const TRAIL_COUNT_MIN := 1
const TRAIL_COUNT_MAX := 2
const TRAIL_LENGTH_MIN := 14
const TRAIL_LENGTH_MAX := 28
const TRAIL_WOBBLE := 0.45
const TRAIL_TWO_WIDE_CHANCE := 0.5

const FIELD_CHANCE := 0.006
const FIELD_RADIUS_MIN := 2.6
const FIELD_RADIUS_MAX := 4.2
const PATCH_GAP := 8.0
# A plot is tilled soil with a light scatter of tufts: the kit has no crop art.
const FIELD_TUFTS_PER_TILE := 1.2
const PATCH_MIN_TUFTS := 10
# Share of the radius that stays fully planted; the rest of the rim thins out.
const FIELD_EDGE_FALLOFF := 0.25
const STARTING_FIELD_RADIUS := 3.0
const STARTING_FIELD_OFFSETS: Array[Vector2i] = [
	Vector2i(4, -10),
	Vector2i(-6, -9),
	Vector2i(8, 6),
	Vector2i(-7, 7),
]

const STARTING_GROVE_TREES := 7

# Small props scattered over the meadow for the kit's dense, cozy read.
const DECOR_CHANCE := 0.018
const DECOR_PROPS := [
	"small_round_bush",
	"berry_bush",
	"blue_flowers_patch",
	"yellow_flowers_patch",
	"red_mushrooms",
	"small_rocks_cluster",
	"mossy_rock",
	"rose_bush",
	"tall_grass_tuft",
]
const WATER_DECOR_CHANCE := 0.06
const WATER_EDGE_DECOR_CHANCE := 0.08
const BOAT_CHANCE := 0.15
# Must match the sprite list in WorldRenderer.
const TUFT_VARIANTS := 1

var rng := RandomNumberGenerator.new()
var moisture := FastNoiseLite.new()
var water_edge := FastNoiseLite.new()

var _occupied := {}


func generate_world(seed_value: int) -> WorldGrid:
	rng.seed = seed_value
	_occupied.clear()
	_setup_noise(seed_value)

	var world := WorldGrid.new(Vector2i(MAP_SIZE, MAP_SIZE))

	_paint_grass_variants(world)
	_paint_camp(world)
	_dig_ponds(world)
	_carve_trails(world)
	_enforce_banks(world)
	_plant_starting_field(world)
	_scatter_fields(world)
	# Grass variants depend on the final terrain, so this runs after every soil
	# and water cell is painted.
	_paint_blend_edge_grass(world)
	_scatter_trees(world)
	_plant_starting_grove(world)
	_scatter_decor(world)
	_scatter_water_decor(world)

	return world


func _setup_noise(seed_value: int) -> void:
	moisture.seed = seed_value + 1
	moisture.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moisture.frequency = 0.05
	moisture.fractal_octaves = 2

	water_edge.seed = seed_value + 3
	water_edge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	water_edge.frequency = 0.18
	water_edge.fractal_octaves = 2


func _paint_grass_variants(world: WorldGrid) -> void:
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			world.set_ground_variant(
				x,
				y,
				GRASS_VARIANT_POOL[rng.randi_range(0, GRASS_VARIANT_POOL.size() - 1)]
			)


func _paint_blend_edge_grass(world: WorldGrid) -> void:
	# Only grass can be cut: a soil or water tile has all four of its quadrants
	# covered, while a grass tile is cut where any of its eight neighbours is not.
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			if world.get_terrain(x, y) != WorldGrid.Terrain.GRASS:
				continue
			if _touches_other_terrain(world, x, y):
				world.set_ground_variant(x, y, BLEND_EDGE_VARIANT)


func _touches_other_terrain(world: WorldGrid, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if world.get_terrain(x + dx, y + dy) != WorldGrid.Terrain.GRASS:
				return true

	return false


func _paint_camp(world: WorldGrid) -> void:
	_paint_disc(world, _center_vector(), CLEARING_RADIUS, WorldGrid.Terrain.SOIL)


func _dig_ponds(world: WorldGrid) -> void:
	var centers: Array[Vector2] = []
	var radii: Array[float] = []
	var target := rng.randi_range(POND_COUNT_MIN, POND_COUNT_MAX)
	var tries := 0
	var margin := POND_RADIUS_MAX + 2.0

	while centers.size() < target and tries < 300:
		tries += 1
		var center := Vector2(
			rng.randf_range(margin, float(MAP_SIZE) - margin),
			rng.randf_range(margin, float(MAP_SIZE) - margin)
		)
		var radius := rng.randf_range(POND_RADIUS_MIN, POND_RADIUS_MAX)

		if center.distance_to(_center_vector()) < POND_FROM_START:
			continue

		var clear := true
		for i in range(centers.size()):
			if center.distance_to(centers[i]) < radius + radii[i] + POND_GAP:
				clear = false
				break

		if not clear:
			continue

		centers.append(center)
		radii.append(radius)
		_paint_pond(world, center, radius)


func _paint_pond(world: WorldGrid, center: Vector2, radius: float) -> void:
	var reach := radius + POND_EDGE_WOBBLE + 1.0

	for y in range(floori(center.y - reach), ceili(center.y + reach) + 1):
		for x in range(floori(center.x - reach), ceili(center.x + reach) + 1):
			if not world.in_bounds(x, y):
				continue
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var wobble := water_edge.get_noise_2d(x, y) * POND_EDGE_WOBBLE

			if distance <= radius + wobble:
				world.set_terrain(x, y, WorldGrid.Terrain.WATER)


func _carve_trails(world: WorldGrid) -> void:
	var count := rng.randi_range(TRAIL_COUNT_MIN, TRAIL_COUNT_MAX)

	for i in range(count):
		var angle := rng.randf_range(0.0, TAU)
		var position := _center_vector() + Vector2.RIGHT.rotated(angle) * (CLEARING_RADIUS + 0.5)
		var length := rng.randi_range(TRAIL_LENGTH_MIN, TRAIL_LENGTH_MAX)
		var two_wide := rng.randf() < TRAIL_TWO_WIDE_CHANCE

		for step in range(length):
			var tile := Vector2i(floori(position.x), floori(position.y))

			if not world.in_bounds(tile.x, tile.y):
				break
			if world.get_terrain(tile.x, tile.y) == WorldGrid.Terrain.WATER:
				break

			_paint_soil(world, tile.x, tile.y)

			if two_wide:
				var side := Vector2.RIGHT.rotated(angle + PI / 2.0) * (1.0 if step % 2 == 0 else -1.0)
				var side_tile := Vector2i(floori(position.x + side.x), floori(position.y + side.y))
				_paint_soil(world, side_tile.x, side_tile.y)

			angle += rng.randf_range(-TRAIL_WOBBLE, TRAIL_WOBBLE)
			position += Vector2.RIGHT.rotated(angle)


func _enforce_banks(world: WorldGrid) -> void:
	# No soil may touch water: the free kit has no dirt-on-water corner set.
	var water: Array[Vector2i] = []

	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			if world.get_terrain(x, y) == WorldGrid.Terrain.WATER:
				water.append(Vector2i(x, y))

	for cell in water:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var neighbor := cell + Vector2i(dx, dy)

				if not world.in_bounds(neighbor.x, neighbor.y):
					continue
				if world.get_terrain(neighbor.x, neighbor.y) != WorldGrid.Terrain.WATER:
					world.set_terrain(neighbor.x, neighbor.y, WorldGrid.Terrain.GRASS)


func _plant_starting_field(world: WorldGrid) -> void:
	for offset in STARTING_FIELD_OFFSETS:
		if _plant_field(world, _map_center() + offset, STARTING_FIELD_RADIUS):
			return


func _plant_starting_grove(world: WorldGrid) -> void:
	_plant_tree_cluster(world, _map_center() + Vector2i(9, 2), 2.0, STARTING_GROVE_TREES)


func _scatter_fields(world: WorldGrid) -> void:
	var centers: Array[Vector2i] = []

	for patch in world.patches:
		centers.append(Vector2i(patch["x"], patch["y"]))

	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			if _distance_to_center(x, y) <= OBJECT_CLEARING_RADIUS:
				continue
			if rng.randf() >= FIELD_CHANCE:
				continue
			if world.get_terrain(x, y) != WorldGrid.Terrain.GRASS:
				continue

			var center := Vector2i(x, y)
			if _too_close(centers, center):
				continue

			if _plant_field(world, center):
				centers.append(center)


func _too_close(centers: Array[Vector2i], center: Vector2i) -> bool:
	# Fields are whole set pieces, so they keep a gap instead of growing into
	# one another.
	for other in centers:
		if Vector2(other - center).length() < PATCH_GAP:
			return true

	return false


func _plant_field(world: WorldGrid, center: Vector2i, radius: float = -1.0) -> bool:
	if radius < 0.0:
		radius = rng.randf_range(FIELD_RADIUS_MIN, FIELD_RADIUS_MAX)

	var reach := ceili(radius) + 1

	# A plot must sit clear of water and its bank, or two blend sets would meet.
	for y in range(center.y - reach, center.y + reach + 1):
		for x in range(center.x - reach, center.x + reach + 1):
			if not world.in_bounds(x, y):
				return false
			if world.get_terrain(x, y) == WorldGrid.Terrain.WATER:
				return false
			if _touches_water(world, x, y):
				return false

	var index := world.patches.size()
	var first_object := world.objects.size()
	var first_id := world.next_object_id
	var changed: Array[Vector2i] = []

	reach = ceili(radius)

	for y in range(center.y - reach, center.y + reach + 1):
		for x in range(center.x - reach, center.x + reach + 1):
			if not world.in_bounds(x, y):
				continue
			# The camp clearing stays open, even where a plot would reach it.
			if _distance_to_center(x, y) <= OBJECT_CLEARING_RADIUS:
				continue

			var distance := Vector2(x - center.x, y - center.y).length()
			if distance > radius:
				continue

			if world.get_terrain(x, y) == WorldGrid.Terrain.WATER:
				continue

			world.set_terrain(x, y, WorldGrid.Terrain.SOIL)
			changed.append(Vector2i(x, y))
			_plant_tufts(world, x, y, index, _patch_cover(distance, radius))

	if world.objects.size() - first_object < PATCH_MIN_TUFTS:
		# Not enough ground to plant on: drop the whole plot, soil included.
		world.remove_objects_from(first_id)
		for tile in changed:
			world.set_terrain(tile.x, tile.y, WorldGrid.Terrain.GRASS)
		return false

	world.patches.append({
		"type": "field",
		"x": center.x,
		"y": center.y,
		"radius": radius
	})

	return true


func _touches_water(world: WorldGrid, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if world.is_water(x + dx, y + dy):
				return true

	return false


func _patch_cover(distance: float, radius: float) -> float:
	var full := radius * (1.0 - FIELD_EDGE_FALLOFF)

	return clampf((radius - distance) / maxf(radius - full, 0.001), 0.0, 1.0)


func _plant_tufts(world: WorldGrid, x: int, y: int, patch: int, cover: float) -> void:
	var amount := roundi(FIELD_TUFTS_PER_TILE * cover * rng.randf_range(0.6, 1.4))

	for i in range(amount):
		world.add_object({
			"type": "tuft",
			"name": "tall_grass_tuft",
			"x": x,
			"y": y,
			"offset": _random_offset(),
			"variant": 0,
			"flip": rng.randf() < 0.5,
			"patch": patch
		})


func _scatter_trees(world: WorldGrid) -> void:
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			if _distance_to_center(x, y) <= OBJECT_CLEARING_RADIUS:
				continue
			if world.get_terrain(x, y) != WorldGrid.Terrain.GRASS:
				continue
			if _has_neighbour(x, y, TREE_SPACING):
				continue
			if rng.randf() >= _tree_density(x, y):
				continue

			_add_tree(world, x, y)


func _tree_density(x: int, y: int) -> float:
	# Damp ground grows woods; dry ground keeps a few trees to build around.
	var wet := clampf(moisture.get_noise_2d(x, y) * 0.5 + 0.5, 0.0, 1.0)

	return lerpf(TREE_DENSITY_MIN, TREE_DENSITY_MAX, wet * wet)


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
			if world.get_terrain(x, y) != WorldGrid.Terrain.GRASS:
				continue
			if Vector2(x - center.x, y - center.y).length() > radius:
				continue
			if _occupied.has(Vector2i(x, y)):
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


func _has_neighbour(x: int, y: int, distance: int) -> bool:
	for dy in range(-distance, distance + 1):
		for dx in range(-distance, distance + 1):
			if _occupied.has(Vector2i(x + dx, y + dy)):
				return true

	return false


func _add_tree(world: WorldGrid, x: int, y: int) -> void:
	var stage := _random_tree_stage()
	var species := ""

	if stage == TreeEntity.TreeStage.MATURE:
		species = MATURE_SPECIES[rng.randi_range(0, MATURE_SPECIES.size() - 1)]

	world.add_object({
		"type": "tree",
		"x": x,
		"y": y,
		"stage": stage,
		"species": species
	})
	_occupied[Vector2i(x, y)] = true


func _random_tree_stage() -> int:
	var roll := rng.randf()

	if roll < 0.15:
		return TreeEntity.TreeStage.SEEDLING

	if roll < 0.40:
		return TreeEntity.TreeStage.YOUNG

	return TreeEntity.TreeStage.MATURE


func _scatter_decor(world: WorldGrid) -> void:
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			if _distance_to_center(x, y) <= OBJECT_CLEARING_RADIUS:
				continue
			if world.get_terrain(x, y) != WorldGrid.Terrain.GRASS:
				continue
			if _occupied.has(Vector2i(x, y)):
				continue
			if rng.randf() >= DECOR_CHANCE:
				continue

			world.add_object({
				"type": "prop",
				"name": DECOR_PROPS[rng.randi_range(0, DECOR_PROPS.size() - 1)],
				"x": x,
				"y": y,
				"offset": _random_offset(),
				"flip": rng.randf() < 0.5
			})
			_occupied[Vector2i(x, y)] = true


func _scatter_water_decor(world: WorldGrid) -> void:
	var boat_placed := false

	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			if world.get_terrain(x, y) != WorldGrid.Terrain.WATER:
				continue
			if rng.randf() >= WATER_DECOR_CHANCE:
				continue

			var deep := _is_open_water(world, x, y, 1)
			var very_deep := _is_open_water(world, x, y, 2)

			var name := ""

			if very_deep and not boat_placed and rng.randf() < BOAT_CHANCE:
				name = "small_wooden_rowboat_floating"
				boat_placed = true
			elif deep:
				name = "lily_pads_lotus"
			elif rng.randf() < WATER_EDGE_DECOR_CHANCE:
				name = "cattail_reeds_bank"

			if name == "":
				continue

			world.add_object({
				"type": "prop",
				"name": name,
				"x": x,
				"y": y,
				"offset": _random_offset(),
				"flip": rng.randf() < 0.5
			})


func _is_open_water(world: WorldGrid, x: int, y: int, clearance: int) -> bool:
	# A 64 px water prop needs room around its foot, or it hangs over the bank.
	for dy in range(-clearance, clearance + 1):
		for dx in range(-clearance, clearance + 1):
			if not world.is_water(x + dx, y + dy):
				return false

	return true


func _paint_disc(
	world: WorldGrid,
	center: Vector2,
	radius: float,
	kind: WorldGrid.Terrain
) -> void:
	for y in range(floori(center.y - radius), ceili(center.y + radius) + 1):
		for x in range(floori(center.x - radius), ceili(center.x + radius) + 1):
			if not world.in_bounds(x, y):
				continue
			if Vector2(x + 0.5, y + 0.5).distance_to(center) > radius:
				continue

			world.set_terrain(x, y, kind)


func _paint_soil(world: WorldGrid, x: int, y: int) -> void:
	if not world.in_bounds(x, y):
		return
	if world.get_terrain(x, y) != WorldGrid.Terrain.GRASS:
		return

	world.set_terrain(x, y, WorldGrid.Terrain.SOIL)


func _random_offset() -> Vector2:
	# Offsets are a share of the tile, so the data stays independent of the
	# renderer's pixel size. Values under 0.5 keep an object in its own tile.
	return Vector2(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45))


func _map_center() -> Vector2i:
	return Vector2i(MAP_SIZE / 2, MAP_SIZE / 2)


func _center_vector() -> Vector2:
	# Centre of the middle tile, in tile space.
	return Vector2(MAP_SIZE / 2 + 0.5, MAP_SIZE / 2 + 0.5)


func _distance_to_center(x: int, y: int) -> float:
	return Vector2(x + 0.5, y + 0.5).distance_to(_center_vector())
