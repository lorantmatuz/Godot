extends Node2D

const WORLD_SEED := 12345

var world_generator := WorldGenerator.new()
var world_renderer: WorldRenderer
var minimap: Minimap
var clock := GameClock.new()
var clock_hud: ClockHud

@onready var camera: CameraController = $Camera2D


func _ready() -> void:
	_setup_camera()

	world_renderer = WorldRenderer.new()
	add_child(world_renderer)

	var world := world_generator.generate_world(
		WORLD_SEED
	)

	world_renderer.display_world(world)
	_setup_hud(world)


func _process(delta: float) -> void:
	# The clock is the only thing that owns time; systems will hang off its
	# ticks, never off this delta. World animation is retimed to the speed so
	# nothing moves at its own pace while the simulation is paused or at 4x.
	clock.advance(delta)
	world_renderer.set_time_scale(clock.speed_scale())


func _setup_hud(world: WorldGrid) -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 10
	add_child(hud)

	clock_hud = ClockHud.new()
	clock_hud.name = "ClockHud"
	hud.add_child(clock_hud)
	clock_hud.setup(clock)
	# KEEP_SIZE keeps the strip at the size setup() chose; the margin holds it
	# off the screen corner.
	clock_hud.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE, 8
	)

	minimap = Minimap.new()
	minimap.name = "Minimap"
	hud.add_child(minimap)
	minimap.setup(world, camera)
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
