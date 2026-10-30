class_name WorldRenderer
extends Node2D

## Draws the generated world with the Cozy World Kit.
##
## The base layer is the 16-variant grass fill. Soil and water are painted as
## overlay terrains: each one gets a hidden "world" TileMapLayer holding one cell
## per tile and a DualGridLayer that turns those cells into the kit's 16 corner
## tiles. The kit's WaterGlints node animates open water.

const TILE_SIZE := 32

const FILL_TILESET := preload("res://assets/cozy_world_kit/tilesets/fills_grass.tres")
const SOIL_TILESET := preload("res://assets/cozy_world_kit/tilesets/grass_dirt.tres")
const WATER_TILESET := preload("res://assets/cozy_world_kit/tilesets/grass_water.tres")
const PAINT_TILESET := preload("res://addons/cozy_world_kit/world_paint.tres")

const SOIL_ATLAS := "res://assets/cozy_world_kit/terrain/atlas/grass_dirt.json"
const WATER_ATLAS := "res://assets/cozy_world_kit/terrain/atlas/grass_water.json"
# llll is pure grass, which the fill layer already draws.
const SKIP_CODES := ["llll"]

const TREE_SCENE := preload("res://scenes/tree.tscn")

# A kit canvas is at most 64 px, and _foot() keeps it within 0.45 tile of its
# tile's centre, so a click on one tile can be covered by a sprite anchored up to
# three tiles above or below it (and two across).
const PICK_REACH_SIDES := 2
const PICK_REACH_VERTICAL := 3

# One glint frame at 1x. The kit's addon animates on real seconds, so the speed
# is applied here by retiming that interval instead of patching the addon.
const GLINT_FRAME_MS := 110.0

const TREE_SEEDLING := preload(
	"res://assets/cozy_world_kit/props/props_32/small_round_bush.png"
)
const TREE_YOUNG := preload(
	"res://assets/cozy_world_kit/props/props_32/round_leafy_oak_tree.png"
)
const TREE_STUMP := preload("res://assets/cozy_world_kit/props/props_32/tree_stump.png")
const TREE_MATURE := {
	"oak": preload("res://assets/cozy_world_kit/props/props_64/large_oak_tree.png"),
	"pine": preload("res://assets/cozy_world_kit/props/props_64/tall_pine_tree.png"),
	"cherry": preload("res://assets/cozy_world_kit/props/props_64/cherry_blossom_tree.png"),
	"willow": preload("res://assets/cozy_world_kit/props/props_64/large_willow_tree.png"),
}

# Must cover every prop name WorldGenerator can emit.
const PROP_TEXTURES := {
	"tall_grass_tuft": preload(
		"res://assets/cozy_world_kit/props/props_32/tall_grass_tuft.png"
	),
	"small_round_bush": TREE_SEEDLING,
	"berry_bush": preload("res://assets/cozy_world_kit/props/props_32/berry_bush.png"),
	"blue_flowers_patch": preload(
		"res://assets/cozy_world_kit/props/props_32/blue_flowers_patch.png"
	),
	"yellow_flowers_patch": preload(
		"res://assets/cozy_world_kit/props/props_32/yellow_flowers_patch.png"
	),
	"red_mushrooms": preload(
		"res://assets/cozy_world_kit/props/props_32/red_mushrooms.png"
	),
	"small_rocks_cluster": preload(
		"res://assets/cozy_world_kit/props/props_32/small_rocks_cluster.png"
	),
	"mossy_rock": preload("res://assets/cozy_world_kit/props/props_32/mossy_rock.png"),
	"rose_bush": preload("res://assets/cozy_world_kit/props/props_32/rose_bush.png"),
	"lily_pads_lotus": preload(
		"res://assets/cozy_world_kit/props/water_64/lily_pads_lotus.png"
	),
	"cattail_reeds_bank": preload(
		"res://assets/cozy_world_kit/props/water_64/cattail_reeds_bank.png"
	),
	"small_wooden_rowboat_floating": preload(
		"res://assets/cozy_world_kit/props/water_64/small_wooden_rowboat_floating.png"
	),
}

var world: WorldGrid

var fill_layer: TileMapLayer
var soil_world: TileMapLayer
var water_world: TileMapLayer
var soil_display: DualGridLayer
var water_display: DualGridLayer
var glints: WaterGlints
# Multiplier the world's own animation runs at; the clock's speed is the only
# source of it, so water never shimmers while a paused simulation sits still.
var time_scale := 1.0
var object_layer: Node2D
# Object id -> spawned node. Data identity lives in WorldGrid; this map is the
# only thing that has to stay in step with it when an object is removed.
var object_nodes := {}
# Trees currently faded for the cutaway, so only the ones that changed are
# touched when the pointer moves.
var _faded := {}


func _ready() -> void:
	_ensure_layers()


func display_world(new_world: WorldGrid) -> void:
	_ensure_layers()
	world = new_world

	_faded.clear()
	_clear_children(object_layer)
	_build_fill()
	_paint_overlay(soil_world, WorldGrid.Terrain.SOIL)
	_paint_overlay(water_world, WorldGrid.Terrain.WATER)
	soil_display.rebuild()
	water_display.rebuild()
	_spawn_objects()


func world_to_grid(pos: Vector2) -> Vector2:
	return pos / TILE_SIZE - Vector2(0.5, 0.5)


func grid_to_world(pos: Vector2) -> Vector2:
	return (pos + Vector2(0.5, 0.5)) * TILE_SIZE


func set_time_scale(scale: float) -> void:
	## Retimes the water shimmer to the game speed: 0 freezes it with a paused
	## simulation, 4x makes it sparkle 4x faster.
	if is_equal_approx(scale, time_scale):
		return

	time_scale = scale

	if glints == null:
		return

	glints.playing = scale > 0.0
	glints.frame_ms = maxi(1, roundi(GLINT_FRAME_MS / maxf(scale, 0.001)))


func _ensure_layers() -> void:
	if fill_layer != null:
		return

	fill_layer = TileMapLayer.new()
	fill_layer.name = "Grass"
	fill_layer.tile_set = FILL_TILESET
	add_child(fill_layer)

	soil_world = _make_paint_layer("SoilPaint")
	soil_display = _make_display_layer("Soil", SOIL_TILESET, SOIL_ATLAS, soil_world)

	water_world = _make_paint_layer("WaterPaint")
	water_display = _make_display_layer("Water", WATER_TILESET, WATER_ATLAS, water_world)

	glints = WaterGlints.new()
	glints.name = "WaterGlints"
	add_child(glints)
	glints.water = water_display

	object_layer = Node2D.new()
	object_layer.name = "Objects"
	object_layer.y_sort_enabled = true
	add_child(object_layer)


func _make_paint_layer(layer_name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = PAINT_TILESET
	add_child(layer)

	return layer


func _make_display_layer(
	layer_name: String,
	tileset: TileSet,
	atlas_json: String,
	source: TileMapLayer
) -> DualGridLayer:
	var layer := DualGridLayer.new()
	layer.name = layer_name
	layer.tile_set = tileset
	layer.world = source
	layer.atlas_json = atlas_json
	layer.skip_codes = PackedStringArray(SKIP_CODES)
	# The world is generated once, so there is nothing to poll for.
	layer.poll_seconds = 0.0
	add_child(layer)

	return layer


func _build_fill() -> void:
	fill_layer.clear()

	for y in range(world.size.y):
		for x in range(world.size.x):
			fill_layer.set_cell(
				Vector2i(x, y),
				0,
				Vector2i(world.get_ground_variant(x, y), 0)
			)


func _paint_overlay(layer: TileMapLayer, kind: WorldGrid.Terrain) -> void:
	layer.clear()

	for y in range(world.size.y):
		for x in range(world.size.x):
			if world.get_terrain(x, y) == kind:
				layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)


func _spawn_objects() -> void:
	object_nodes.clear()

	for obj in world.objects:
		spawn_object(obj["id"])


func spawn_object(id: int) -> Node:
	## Builds one object's node. The world fill uses it for everything, and a
	## placement uses it for the single building it just added, so adding to the
	## map never rebuilds the map.
	var obj_data: Dictionary = world.objects_by_id.get(id, {})

	if obj_data.is_empty():
		return null

	match obj_data["type"]:
		"tree":
			_spawn_tree(obj_data)
		"tuft", "prop":
			_spawn_prop(obj_data)
		"building":
			_spawn_building(obj_data)
		_:
			return null

	return object_nodes.get(id)


func _spawn_tree(obj_data: Dictionary) -> void:
	var tree := TREE_SCENE.instantiate() as TreeEntity
	var texture := tree_texture(obj_data["stage"], obj_data.get("species", ""))

	tree.position = _foot(obj_data)
	tree.species = obj_data.get("species", "")
	tree.set_growth_stage(obj_data["stage"])
	object_layer.add_child(tree)
	tree.apply_texture(texture)
	object_nodes[obj_data["id"]] = tree


func _spawn_prop(obj_data: Dictionary) -> void:
	var texture: Texture2D = PROP_TEXTURES.get(obj_data["name"])

	if texture == null:
		push_warning("WorldRenderer: no texture for prop %s" % obj_data["name"])
		return

	var sprite := Sprite2D.new()
	sprite.name = obj_data["name"]
	sprite.position = _foot(obj_data)
	sprite.flip_h = bool(obj_data.get("flip", false))
	object_layer.add_child(sprite)
	_anchor_to_art(sprite, texture)
	object_nodes[obj_data["id"]] = sprite


func _spawn_building(obj_data: Dictionary) -> void:
	var def := BuildingDefs.get_def(obj_data.get("name", ""))
	var texture: Texture2D = def.get("texture")

	if texture == null:
		push_warning("WorldRenderer: no texture for building %s" % obj_data.get("name", ""))
		return

	var sprite := Sprite2D.new()
	sprite.name = def.get("name", "Building")
	sprite.position = _building_foot(obj_data)
	object_layer.add_child(sprite)
	_apply_texture(sprite, texture)
	object_nodes[obj_data["id"]] = sprite


func _building_foot(obj_data: Dictionary) -> Vector2:
	# A building's foot is the bottom centre of its whole footprint, not of the
	# anchor tile, or a 2x2 stand-in would hang off its plot.
	var size: Vector2i = obj_data.get("size", Vector2i.ONE)

	return Vector2(
		(obj_data["x"] + size.x / 2.0) * TILE_SIZE,
		(obj_data["y"] + size.y) * TILE_SIZE
	)


func cutaway(point: Vector2) -> void:
	## Fades every tree whose canopy covers a world point and restores the rest,
	## so a building behind a tree is not lost. Costs one rect test per tree and
	## touches only the trees that changed since the last call.
	for id in _faded.keys().duplicate():
		var old: Node = object_nodes.get(id)

		if is_instance_valid(old):
			old.set_faded(false)
		_faded.erase(id)

	for id in object_nodes:
		var node: Node = object_nodes[id]

		if not (node is TreeEntity) or not is_instance_valid(node):
			continue
		if not _pick_rect(node).has_point(point):
			continue

		node.set_faded(true)
		_faded[id] = true


func remove_object(id: int) -> bool:
	## Drops the node for an object the world has already removed.
	_faded.erase(id)

	var node: Node = object_nodes.get(id)

	if not is_instance_valid(node):
		object_nodes.erase(id)
		return false

	object_nodes.erase(id)
	node.queue_free()

	return true


func pick(global_point: Vector2) -> int:
	## The id of the object drawn under a world-space point, or -1 for empty
	## ground. The test is the sprite's visible rect, so a canopy is as clickable
	## as a trunk, and the front-most object (greatest foot y) wins.
	if world == null:
		return -1

	var tile := Vector2i(
		floori(global_point.x / TILE_SIZE),
		floori(global_point.y / TILE_SIZE)
	)
	var best_id := -1
	var best_foot := -INF

	for y in range(tile.y - PICK_REACH_VERTICAL, tile.y + PICK_REACH_VERTICAL + 1):
		for x in range(tile.x - PICK_REACH_SIDES, tile.x + PICK_REACH_SIDES + 1):
			for id in world.objects_by_tile.get(Vector2i(x, y), []):
				var node: Node2D = object_nodes.get(id)

				if not is_instance_valid(node):
					continue

				var foot := node.global_position.y

				if foot < best_foot:
					continue
				# A shared foot (two props nudged into the same spot) resolves by
				# id, so picking does not depend on iteration order.
				if is_equal_approx(foot, best_foot) and id < best_id:
					continue
				if not _pick_rect(node).has_point(global_point):
					continue

				best_foot = foot
				best_id = id

	return best_id


func _pick_rect(node: Node2D) -> Rect2:
	# Every prop draws upwards from its foot and _apply_texture sets the offset
	# to (-w/2, -h), so the visible rect starts at the sprite's position + offset.
	var sprite := node as Sprite2D

	if sprite == null:
		sprite = node.get_node_or_null("Sprite2D") as Sprite2D

	if sprite == null or sprite.texture == null:
		return Rect2()

	return Rect2(sprite.global_position + sprite.offset, sprite.texture.get_size())


func tree_texture(stage: int, species: String) -> Texture2D:
	match stage:
		TreeEntity.TreeStage.SEEDLING:
			return TREE_SEEDLING
		TreeEntity.TreeStage.YOUNG:
			return TREE_YOUNG
		TreeEntity.TreeStage.STUMP:
			return TREE_STUMP
		_:
			return TREE_MATURE.get(species, TREE_MATURE["oak"])


static func art_offset(texture: Texture2D) -> Vector2:
	## Anchors the visible art — not the whole canvas — at the tile's bottom
	## centre. The kit pads its canvases unevenly (mushrooms carry 4 px of empty
	## canvas below them, a mossy rock 6 px above), so anchoring the canvas left
	## small props reading as if they stood in the row above their own tile.
	var used := texture.get_image().get_used_rect()

	return Vector2(-(used.position.x + used.size.x / 2.0), -used.end.y)


func _anchor_to_art(sprite: Sprite2D, texture: Texture2D) -> void:
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = art_offset(texture)


func _apply_texture(sprite: Sprite2D, texture: Texture2D) -> void:
	# The kit anchors every prop at the bottom centre of its canvas, which is
	# also the node position, so y-sorting matches the visible feet.
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = Vector2(-texture.get_width() / 2.0, -texture.get_height())


func _foot(obj_data: Dictionary) -> Vector2:
	var offset: Vector2 = obj_data.get("offset", Vector2.ZERO) * TILE_SIZE

	return Vector2(
		(obj_data["x"] + 0.5) * TILE_SIZE,
		(obj_data["y"] + 1.0) * TILE_SIZE
	) + offset


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
