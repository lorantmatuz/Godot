extends Node2D

const WORLD_SEED := 12345

@onready var camera: Camera2D = $Camera2D

var world_generator := WorldGenerator.new()
var world_renderer: WorldRenderer


func _ready() -> void:
	_setup_camera()

	world_renderer = WorldRenderer.new()
	add_child(world_renderer)

	var world_data := world_generator.generate_world(
		WORLD_SEED
	)

	world_renderer.display_world(world_data)


func _setup_camera() -> void:
	var world_size := WorldGenerator.MAP_SIZE * WorldRenderer.TILE_SIZE

	camera.position = Vector2.ONE * world_size / 2.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = world_size
	camera.limit_bottom = world_size
	camera.reset_smoothing()
