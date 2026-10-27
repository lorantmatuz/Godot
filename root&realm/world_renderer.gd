
extends Node2D
class_name WorldRenderer

const TILE_SIZE := 64
const TREE_SCENE = preload("res://scenes/tree.tscn")

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
		if obj["type"] == "tree":
			spawn_tree(obj["x"], obj["y"])


func spawn_tree(x: int, y: int) -> void:
	var tree = TREE_SCENE.instantiate()

	tree.position = Vector2(
		(x + 0.5) * TILE_SIZE,
		(y + 0.5) * TILE_SIZE
	)

	add_child(tree)


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

	# Temporary stone visuals.
	for obj in objects:
		if obj["type"] != "stone":
			continue

		var center := Vector2(
			(obj["x"] + 0.5) * TILE_SIZE,
			(obj["y"] + 0.5) * TILE_SIZE
		)

		draw_circle(
			center,
			8.0,
			Color("#888b83")
		)

		draw_circle(
			center + Vector2(-3, -2),
			4.0,
			Color("#b3b4a8")
		)
