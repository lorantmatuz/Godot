extends Node2D
class_name WorldRenderer

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
	"small_round_bush": preload(
		"res://assets/cozy_world_kit/props/props_32/small_round_bush.png"
	),
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
var object_layer: Node2D


func _ready() -> void:
	_ensure_layers()


func display_world(new_world: WorldGrid) -> void:
	_ensure_layers()
	world = new_world

	_clear_children(object_layer)
	_build_fill()
	_paint_overlay(soil_world, WorldGrid.Terrain.SOIL)
	_paint_overlay(water_world, WorldGrid.Terrain.WATER)
	soil_display.rebuild()
	water_display.rebuild()
	_spawn_objects()


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
	for obj in world.objects:
		match obj["type"]:
			"tree":
				_spawn_tree(obj)
			"tuft", "prop":
				_spawn_prop(obj)


func _spawn_tree(obj_data: Dictionary) -> void:
	var tree := TREE_SCENE.instantiate() as TreeEntity
	var texture := tree_texture(obj_data["stage"], obj_data.get("species", ""))

	tree.position = _foot(obj_data)
	tree.species = obj_data.get("species", "")
	tree.set_growth_stage(obj_data["stage"])
	object_layer.add_child(tree)
	tree.apply_texture(texture)


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
	_apply_texture(sprite, texture)


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
