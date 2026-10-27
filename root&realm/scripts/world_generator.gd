extends RefCounted
class_name WorldGenerator

const MAP_SIZE := 64

var rng := RandomNumberGenerator.new()


func generate_world(seed_value: int) -> Dictionary:
	rng.seed = seed_value

	var terrain: Array = []
	var objects: Array = []

	for y in range(MAP_SIZE):
		var row: Array = []

		for x in range(MAP_SIZE):
			row.append(rng.randi_range(0, 3))

			# Keep the starting clearing empty.
			var distance := Vector2(
				x - MAP_SIZE / 2.0,
				y - MAP_SIZE / 2.0
			).length()

			if distance < 5.0:
				continue

			var roll := rng.randf()

			if roll < 0.075:
				objects.append({
					"type": "tree",
					"x": x,
					"y": y,
					"stage": _random_tree_stage()
				})
			elif roll < 0.09:
				objects.append({
					"type": "stone",
					"x": x,
					"y": y
				})

		terrain.append(row)

	return {
		"terrain": terrain,
		"objects": objects
	}


func _random_tree_stage() -> int:
	var roll := rng.randf()

	if roll < 0.15:
		return TreeEntity.TreeStage.SEEDLING

	if roll < 0.40:
		return TreeEntity.TreeStage.YOUNG

	return TreeEntity.TreeStage.MATURE
