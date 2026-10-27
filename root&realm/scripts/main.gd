
extends Node2D

const WORLD_SEED := 12345

var world_generator := WorldGenerator.new()
var world_renderer: WorldRenderer


func _ready() -> void:
	world_renderer = WorldRenderer.new()
	add_child(world_renderer)

	var world_data := world_generator.generate_world(
		WORLD_SEED
	)

	world_renderer.display_world(world_data)
