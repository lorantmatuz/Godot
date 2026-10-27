extends Node2D
class_name WorldRenderer

const TILE_SIZE := 64
const TREE_SCENE = preload("res://scenes/tree.tscn")
const ROCK_SCENE = preload("res://scenes/rock.tscn")

var terrain: Array = []
var objects: Array = []


func display_world(world_data: Dictionary) -> void:
	terrain = world_data["terrain"]
	objects = world_data["objects"]

	# Remove previously spawned objects.
	for child in get_children():
		child.queue_free()

	queue_redraw()

	for obj in objects:
		match obj["type"]:
			"tree":
				spawn_object(obj, TREE_SCENE)
			"stone":
				spawn_object(obj, ROCK_SCENE)


func spawn_object(obj_data: Dictionary, scene: PackedScene) -> void:
	var obj = scene.instantiate()

	obj.position = Vector2(
		(obj_data["x"] + 0.5) * TILE_SIZE,
		(obj_data["y"] + 0.5) * TILE_SIZE
	)

	add_child(obj)

	if obj is TreeEntity:
		obj.set_growth_stage(obj_data["stage"])


func _draw() -> void:
	if terrain.is_empty():
		return

	var grass_colors := [
		Color("#78965b"),
		Color("#819d62"),
		Color("#739154"),
		Color("#86a267")
	]

	for y in range(terrain.size()):
		for x in range(terrain[y].size()):
			var rect := Rect2(
				x * TILE_SIZE,
				y * TILE_SIZE,
				TILE_SIZE,
				TILE_SIZE
			)

			draw_rect(
				rect,
				grass_colors[terrain[y][x]]
			)
