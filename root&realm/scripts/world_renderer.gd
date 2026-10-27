extends Node2D
class_name WorldRenderer

const TILE_SIZE := 64
const SHADE_BLOCK := 4
const GRASS_VARIANT_COUNT := 4
const WATER_TILE_START := 4
const WATER_TILE_VARIANTS := 16
const ROCK_TILE := 20
const FOREST_TILE := 21
const GROUND_TILE_COUNT := 22
const WATER_EDGE := 4

const DECAL_DENSITY := 0.06
const DECAL_SEED := 424242

const TREE_SCENE = preload("res://scenes/tree.tscn")
const ROCK_SCENE = preload("res://scenes/rock.tscn")
const GRASS_SCENE = preload("res://scenes/grass.tscn")

const GRASS_COLOR := Color("#7a9760")
const WATER_COLOR := Color("#4f7f8c")
const ROCK_COLOR := Color("#7d7a6e")
const FOREST_COLOR := Color("#5f7a48")

var world: WorldGrid

var ground: TileMapLayer
var decals: Node2D
var object_layer: Node2D

var _ground_source_id := -1
var _decal_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_ensure_layers()


func display_world(new_world: WorldGrid) -> void:
	_ensure_layers()
	world = new_world

	_clear_children(decals)
	_clear_children(object_layer)

	_decal_rng.seed = DECAL_SEED

	_build_ground()
	_spawn_decals()
	_spawn_objects()


func _ensure_layers() -> void:
	if ground != null:
		return

	ground = TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = _build_ground_tileset()
	add_child(ground)

	decals = Node2D.new()
	decals.name = "Decals"
	add_child(decals)

	object_layer = Node2D.new()
	object_layer.name = "Objects"
	object_layer.y_sort_enabled = true
	add_child(object_layer)


func _build_ground() -> void:
	ground.clear()

	for y in range(world.size.y):
		for x in range(world.size.x):
			ground.set_cell(
				Vector2i(x, y),
				_ground_source_id,
				_ground_atlas_coord(x, y)
			)


func _ground_atlas_coord(x: int, y: int) -> Vector2i:
	match world.get_terrain(x, y):
		WorldGrid.Terrain.WATER:
			return Vector2i(WATER_TILE_START + _water_mask(x, y), 0)
		WorldGrid.Terrain.ROCKY:
			return Vector2i(ROCK_TILE, 0)
		WorldGrid.Terrain.FOREST_FLOOR:
			return Vector2i(FOREST_TILE, 0)
		_:
			return Vector2i(_grass_variant(x, y), 0)


func _water_mask(x: int, y: int) -> int:
	var mask := 0

	if _is_land(x, y - 1):
		mask |= 1
	if _is_land(x + 1, y):
		mask |= 2
	if _is_land(x, y + 1):
		mask |= 4
	if _is_land(x - 1, y):
		mask |= 8

	return mask


func _is_land(x: int, y: int) -> bool:
	if not world.in_bounds(x, y):
		return false

	return world.get_terrain(x, y) != WorldGrid.Terrain.WATER


func _grass_variant(x: int, y: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663)) % GRASS_VARIANT_COUNT


func _build_ground_tileset() -> TileSet:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = _build_ground_atlas()
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	for column in range(GROUND_TILE_COUNT):
		atlas.create_tile(Vector2i(column, 0))

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	_ground_source_id = tile_set.add_source(atlas)

	return tile_set


func _build_ground_atlas() -> ImageTexture:
	var image := Image.create(
		TILE_SIZE * GROUND_TILE_COUNT,
		TILE_SIZE,
		false,
		Image.FORMAT_RGBA8
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331

	for column in range(GRASS_VARIANT_COUNT):
		_fill_ground_tile(image, column, _tinted(GRASS_COLOR, rng.randf_range(-0.015, 0.015)), rng)

	for mask in range(WATER_TILE_VARIANTS):
		_fill_water_tile(image, WATER_TILE_START + mask, mask, rng)

	_fill_ground_tile(image, ROCK_TILE, ROCK_COLOR, rng)
	_fill_ground_tile(image, FOREST_TILE, FOREST_COLOR, rng)

	return ImageTexture.create_from_image(image)


func _fill_ground_tile(
	image: Image,
	column: int,
	base: Color,
	rng: RandomNumberGenerator
) -> void:
	var origin := Vector2i(column * TILE_SIZE, 0)
	var blocks := TILE_SIZE / SHADE_BLOCK

	for block_y in range(blocks):
		for block_x in range(blocks):
			var color := _tinted(base, rng.randf_range(-0.018, 0.018))

			for pixel_y in range(SHADE_BLOCK):
				for pixel_x in range(SHADE_BLOCK):
					image.set_pixel(
						origin.x + block_x * SHADE_BLOCK + pixel_x,
						origin.y + block_y * SHADE_BLOCK + pixel_y,
						color
					)

	for speck in range(24):
		var x := rng.randi_range(0, TILE_SIZE - 1)
		var y := rng.randi_range(0, TILE_SIZE - 1)
		image.set_pixel(origin.x + x, origin.y + y, _tinted(base, rng.randf_range(-0.05, 0.05)))


func _fill_water_tile(
	image: Image,
	column: int,
	mask: int,
	rng: RandomNumberGenerator
) -> void:
	_fill_ground_tile(image, column, WATER_COLOR, rng)

	var origin := Vector2i(column * TILE_SIZE, 0)
	var edge := WATER_COLOR.darkened(0.16)

	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var on_edge := (
				((mask & 1) != 0 and y < WATER_EDGE)
				or ((mask & 2) != 0 and x >= TILE_SIZE - WATER_EDGE)
				or ((mask & 4) != 0 and y >= TILE_SIZE - WATER_EDGE)
				or ((mask & 8) != 0 and x < WATER_EDGE)
			)

			if on_edge:
				image.set_pixel(origin.x + x, origin.y + y, edge)


func _tinted(base: Color, amount: float) -> Color:
	return Color(
		clampf(base.r + amount, 0.0, 1.0),
		clampf(base.g + amount, 0.0, 1.0),
		clampf(base.b + amount, 0.0, 1.0)
	)


func _spawn_decals() -> void:
	var center := Vector2(world.size) / 2.0

	for y in range(world.size.y):
		for x in range(world.size.x):
			if world.get_terrain(x, y) != WorldGrid.Terrain.GRASS:
				continue

			# Keep the starting clearing clean for the camp.
			if Vector2(x, y).distance_to(center) <= WorldGenerator.CLEARING_RADIUS:
				continue

			if _decal_rng.randf() >= DECAL_DENSITY:
				continue

			var decal = GRASS_SCENE.instantiate()
			decal.position = _tile_center(x, y) + Vector2(
				_decal_rng.randf_range(-18.0, 18.0),
				_decal_rng.randf_range(-18.0, 18.0)
			)
			decal.get_node("Sprite2D").flip_h = _decal_rng.randf() < 0.5
			decals.add_child(decal)


func _spawn_objects() -> void:
	for obj in world.objects:
		match obj["type"]:
			"tree":
				_spawn_object(obj, TREE_SCENE)
			"stone":
				_spawn_object(obj, ROCK_SCENE)


func _spawn_object(obj_data: Dictionary, scene: PackedScene) -> void:
	var obj = scene.instantiate()

	obj.position = _tile_center(obj_data["x"], obj_data["y"])
	object_layer.add_child(obj)

	if obj is TreeEntity:
		obj.set_growth_stage(obj_data["stage"])


func _tile_center(x: int, y: int) -> Vector2:
	return Vector2(
		(x + 0.5) * TILE_SIZE,
		(y + 0.5) * TILE_SIZE
	)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
