extends Node2D

const WORLD_SEED := 12345

@onready var camera: CameraController = $Camera2D

var world_generator := WorldGenerator.new()
var world_renderer: WorldRenderer
var minimap: Minimap


func _ready() -> void:
	_setup_camera()

	world_renderer = WorldRenderer.new()
	add_child(world_renderer)

	var world := world_generator.generate_world(
		WORLD_SEED
	)

	world_renderer.display_world(world)
	_setup_minimap(world)


func _setup_minimap(world: WorldGrid) -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 10
	add_child(hud)

	minimap = Minimap.new()
	minimap.name = "Minimap"
	hud.add_child(minimap)
	minimap.setup(world, camera)
	# KEEP_SIZE keeps the size setup() derived from the map; the margin holds it
	# off the screen corner.
	minimap.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 8
	)


func _setup_camera() -> void:
	var world_size := WorldGenerator.MAP_SIZE * WorldRenderer.TILE_SIZE

	camera.position = Vector2.ONE * world_size / 2.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = world_size
	camera.limit_bottom = world_size
	camera.reset_smoothing()
