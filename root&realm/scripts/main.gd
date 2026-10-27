
extends Node2D

const TILE_SIZE := 32
const MAP_SIZE := 64

var rng := RandomNumberGenerator.new()
var terrain: Array = []
var objects: Array = []

func _ready() -> void:
	rng.seed = 12345
	generate_world()
	queue_redraw()


func generate_world() -> void:
	terrain.clear()
	objects.clear()

	for y in range(MAP_SIZE):
		var row: Array = []

		for x in range(MAP_SIZE):
			# Slight variation in grass color
			var grass := rng.randi_range(0, 3)
			row.append(grass)

			# Leave a clearing around the starting camp
			var distance := Vector2(x - 32, y - 32).length()
			if distance < 5:
				continue

			var roll := rng.randf()

			if roll < 0.075:
				objects.append({
					"type": "tree",
					"x": x,
					"y": y
				})
			elif roll < 0.09:
				objects.append({
					"type": "stone",
					"x": x,
					"y": y
				})

		terrain.append(row)


func _draw() -> void:
	var grass_colors := [
		Color("#78965b"),
		Color("#819d62"),
		Color("#739154"),
		Color("#86a267")
	]

	# Draw the terrain
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
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

	# Draw trees and stone deposits
	for obj in objects:
		var center := Vector2(
			(obj["x"] + 0.5) * TILE_SIZE,
			(obj["y"] + 0.5) * TILE_SIZE
		)

		if obj["type"] == "tree":
			# Shadow
			draw_circle(
				center + Vector2(3, 5),
				12,
				Color("#526748")
			)

			# Tree canopy
			draw_circle(
				center,
				13,
				Color("#365d38")
			)
			draw_circle(
				center + Vector2(-4, -4),
				7,
				Color("#527b43")
			)

		elif obj["type"] == "stone":
			draw_circle(
				center,
				8,
				Color("#888b83")
			)
			draw_circle(
				center + Vector2(-3, -2),
				4,
				Color("#b3b4a8")
			)
