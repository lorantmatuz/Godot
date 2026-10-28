extends Node2D
class_name WorldRenderer

const TILE_SIZE := 64

# Ground shape, in land share units: one tile of ground is 1.0.
const JITTER := 12.0
const SHORE_SHALLOW := Vector2(0.0, 0.3)
const SHORE_SAND := Vector2(0.3, 0.48)
const SHORE_LAND := Vector2(0.48, 0.68)
const LAND_SHARPNESS := 16.0
const ROCK_RIM_WIDTH := 0.8
const ROCK_RIM_STRENGTH := 0.7

# Keep JITTER / (TILE_SIZE / JITTER_CELLS_PER_TILE) below ~0.5, or the warp
# folds the terrain lookup and some borders smear into foggy bands.
const JITTER_CELLS_PER_TILE := 1
const JITTER_SEED := 424242
const GRAIN_SIZE := 256
const GRAIN_SEED := 733715

const GROUND_SHADER = preload("res://shaders/ground.gdshader")

const TREE_SCENE = preload("res://scenes/tree.tscn")
const ROCK_SCENE = preload("res://scenes/rock.tscn")
# Rock sprite order; WorldGenerator.ROCK_VARIANTS must match this size.
const ROCK_TEXTURES: Array[Texture2D] = [
	preload("res://assets/rocks/rock1.tres"),
	preload("res://assets/rocks/rock2.tres"),
	preload("res://assets/rocks/rock3.tres"),
	preload("res://assets/rocks/rock4.tres"),
	preload("res://assets/rocks/rock5.tres")
]
const GRASS_SCENE = preload("res://scenes/grass.tscn")
# Tuft variant order; WorldGenerator.TUFT_VARIANTS must match this size.
const GRASS_TEXTURES: Array[Texture2D] = [
	preload("res://assets/grass/grass1.tres"),
	preload("res://assets/grass/grass2.tres"),
	preload("res://assets/grass/grass3.tres"),
	preload("res://assets/grass/grass4.tres")
]

# Every resource object is spawned as its own y-sorted scene, so tufts, stones
# and trees sort against each other exactly as they would in a tilemap.
const OBJECT_SCENES := {
	"tree": TREE_SCENE,
	"tuft": GRASS_SCENE,
	"stone": ROCK_SCENE
}

# Which sprite list a patch object picks from, keyed by object type.
const VARIANT_TEXTURES := {
	"tuft": GRASS_TEXTURES,
	"stone": ROCK_TEXTURES
}

const GRASS_COLOR := Color("#7a9760")
const FOREST_COLOR := Color("#6b8753")
const ROCK_COLOR := Color("#7d7a6e")
const WATER_COLOR := Color("#4f7f8c")
const SHALLOW_COLOR := Color("#628e99")
const SAND_COLOR := Color("#b0a077")
const ROCK_RIM_COLOR := Color("#5f5c50")

var world: WorldGrid

var ground: Sprite2D
var object_layer: Node2D

var _ground_material: ShaderMaterial
var _jitter: ImageTexture


func _ready() -> void:
	_ensure_layers()


func display_world(new_world: WorldGrid) -> void:
	_ensure_layers()
	world = new_world

	_clear_children(object_layer)

	_build_ground()
	_spawn_objects()


func _ensure_layers() -> void:
	if ground != null:
		return

	# A one pixel white sprite is only a canvas for the shader; all colour
	# comes from the terrain texture and the noise fields.
	var pixel := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	pixel.fill(Color.WHITE)

	_ground_material = ShaderMaterial.new()
	_ground_material.shader = GROUND_SHADER
	_ground_material.set_shader_parameter("tile_size", float(TILE_SIZE))
	_ground_material.set_shader_parameter("jitter_amount", JITTER)
	_ground_material.set_shader_parameter("jitter_cells_per_tile", float(JITTER_CELLS_PER_TILE))
	_ground_material.set_shader_parameter("shore_shallow", SHORE_SHALLOW)
	_ground_material.set_shader_parameter("shore_sand", SHORE_SAND)
	_ground_material.set_shader_parameter("shore_land", SHORE_LAND)
	_ground_material.set_shader_parameter("land_sharpness", LAND_SHARPNESS)
	_ground_material.set_shader_parameter("rock_rim_width", ROCK_RIM_WIDTH)
	_ground_material.set_shader_parameter("rock_rim_strength", ROCK_RIM_STRENGTH)
	_ground_material.set_shader_parameter(
		"grain_tex",
		_noise_texture(Vector2i.ONE * GRAIN_SIZE, Image.FORMAT_R8, GRAIN_SEED)
	)
	_ground_material.set_shader_parameter("water_color", WATER_COLOR)
	_ground_material.set_shader_parameter("shallow_color", SHALLOW_COLOR)
	_ground_material.set_shader_parameter("sand_color", SAND_COLOR)
	_ground_material.set_shader_parameter("grass_color", GRASS_COLOR)
	_ground_material.set_shader_parameter("forest_color", FOREST_COLOR)
	_ground_material.set_shader_parameter("rock_color", ROCK_COLOR)
	_ground_material.set_shader_parameter("rock_rim_color", ROCK_RIM_COLOR)

	ground = Sprite2D.new()
	ground.name = "Ground"
	ground.centered = false
	ground.texture = ImageTexture.create_from_image(pixel)
	ground.material = _ground_material
	add_child(ground)

	object_layer = Node2D.new()
	object_layer.name = "Objects"
	object_layer.y_sort_enabled = true
	add_child(object_layer)


func _build_ground() -> void:
	# Terrain boundaries are computed by the shader, so the whole ground costs
	# one small texture upload instead of a per-block loop.
	_ground_material.set_shader_parameter(
		"terrain_tex",
		ImageTexture.create_from_image(
			Image.create_from_data(
				world.size.x,
				world.size.y,
				false,
				Image.FORMAT_R8,
				world.terrain
			)
		)
	)
	_ground_material.set_shader_parameter("jitter_tex", _get_jitter_texture())
	_ground_material.set_shader_parameter("tile_count", Vector2(world.size))

	ground.scale = Vector2(world.size) * TILE_SIZE


func _get_jitter_texture() -> ImageTexture:
	var size := world.size * JITTER_CELLS_PER_TILE + Vector2i.ONE

	if _jitter == null or _jitter.get_size() != Vector2(size):
		_jitter = _noise_texture(size, Image.FORMAT_RG8, JITTER_SEED)

	return _jitter


func _noise_texture(size: Vector2i, format: Image.Format, seed_value: int) -> ImageTexture:
	var channels := 2 if format == Image.FORMAT_RG8 else 1
	var data := PackedByteArray()
	data.resize(size.x * size.y * channels)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	for i in range(data.size()):
		data[i] = rng.randi_range(0, 255)

	return ImageTexture.create_from_image(
		Image.create_from_data(size.x, size.y, false, format, data)
	)


func _spawn_objects() -> void:
	for obj in world.objects:
		var scene: PackedScene = OBJECT_SCENES.get(obj["type"])

		if scene != null:
			_spawn_object(obj, scene)


func _spawn_object(obj_data: Dictionary, scene: PackedScene) -> void:
	var obj = scene.instantiate()
	var offset: Vector2 = obj_data.get("offset", Vector2.ZERO) * TILE_SIZE

	obj.position = _tile_center(obj_data["x"], obj_data["y"]) + offset
	object_layer.add_child(obj)

	if obj is TreeEntity:
		obj.set_growth_stage(obj_data["stage"])
	else:
		_apply_variant(obj, obj_data)


func _apply_variant(obj: Node2D, obj_data: Dictionary) -> void:
	var textures: Array = VARIANT_TEXTURES.get(obj_data["type"], [])

	if textures.is_empty():
		return

	var sprite: Sprite2D = obj.get_node("Sprite2D")
	var variant: int = obj_data.get("variant", 0)

	sprite.texture = textures[variant % textures.size()]
	sprite.flip_h = bool(obj_data.get("flip", false))


func _tile_center(x: int, y: int) -> Vector2:
	return Vector2(
		(x + 0.5) * TILE_SIZE,
		(y + 0.5) * TILE_SIZE
	)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
