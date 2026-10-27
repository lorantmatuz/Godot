extends SceneTree

# Headless smoke test: godot --headless --path "root&realm" --script res://tests/smoke_test.gd

const WORLD_SEED := 12345
const TILE_SIZE := 64

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_test_generation()
	await _test_placement()
	await _test_main_scene()
	print("smoke test: ", "FAIL (%d)" % failures if failures > 0 else "PASS")
	quit(1 if failures > 0 else 0)


func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		failures += 1
	print(("  ok   " if ok else "  FAIL ") + label + ("  [" + detail + "]" if detail != "" else ""))


func _test_generation() -> void:
	print("world generation")
	var first := WorldGenerator.new().generate_world(WORLD_SEED)
	var second := WorldGenerator.new().generate_world(WORLD_SEED)
	var other := WorldGenerator.new().generate_world(WORLD_SEED + 1)

	_check("same seed reproduces the terrain", first["terrain"] == second["terrain"])
	_check("same seed reproduces the objects", first["objects"] == second["objects"])
	_check(
		"a different seed changes the world",
		first["terrain"] != other["terrain"] or first["objects"] != other["objects"]
	)


func _test_placement() -> void:
	print("object placement")
	var world := WorldGenerator.new().generate_world(WORLD_SEED)
	var terrain: Array = world["terrain"]
	var objects: Array = world["objects"]

	_check("terrain has 64 rows", terrain.size() == WorldGenerator.MAP_SIZE, str(terrain.size()))

	var square := true
	for row in terrain:
		if row.size() != WorldGenerator.MAP_SIZE:
			square = false
	_check("every terrain row has 64 tiles", square)

	var types := {}
	var stages := {}
	var known_types := true
	var in_bounds := true
	var clearing_empty := true

	for obj in objects:
		types[obj["type"]] = types.get(obj["type"], 0) + 1

		if obj["type"] != "tree" and obj["type"] != "stone":
			known_types = false

		var tile := Vector2(obj["x"], obj["y"])
		if (
			tile.x < 0 or tile.x >= WorldGenerator.MAP_SIZE
			or tile.y < 0 or tile.y >= WorldGenerator.MAP_SIZE
		):
			in_bounds = false

		var center := Vector2.ONE * WorldGenerator.MAP_SIZE / 2.0
		if tile.distance_to(center) < 5.0:
			clearing_empty = false

		if obj["type"] == "tree":
			stages[obj["stage"]] = true

	_check(
		"the map contains trees and stone",
		types.get("tree", 0) > 0 and types.get("stone", 0) > 0,
		str(types)
	)
	_check("only trees and stone spawn", known_types, str(types.keys()))
	_check("all objects are inside the map", in_bounds)
	_check("the starting clearing is empty", clearing_empty)
	_check("trees are spread across growth stages", stages.size() >= 2, str(stages.keys()))


func _test_main_scene() -> void:
	print("main scene")
	var scene: PackedScene = load("res://scenes/levels/main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame

	var camera: Camera2D = main.get_node("Camera2D")
	var world_size := WorldGenerator.MAP_SIZE * TILE_SIZE

	_check(
		"camera starts at the map center",
		camera.position.is_equal_approx(Vector2.ONE * world_size / 2.0),
		str(camera.position)
	)
	_check(
		"camera is clamped to the map edges",
		camera.limit_left == 0
		and camera.limit_top == 0
		and camera.limit_right == world_size
		and camera.limit_bottom == world_size,
		"limits=%d,%d,%d,%d" % [
			camera.limit_left, camera.limit_top,
			camera.limit_right, camera.limit_bottom
		]
	)

	var renderer = main.world_renderer
	_check(
		"renderer spawned every object",
		renderer.get_child_count() == renderer.objects.size(),
		"%d spawned / %d objects" % [renderer.get_child_count(), renderer.objects.size()]
	)

	var staged_trees := {}
	var visuals_match := true

	for child in renderer.get_children():
		if not (child is TreeEntity):
			continue

		staged_trees[child.growth_stage] = true

		var sprite: Sprite2D = child.get_node("Sprite2D")
		if sprite.texture != _texture_for_stage(child, child.growth_stage):
			visuals_match = false

	_check("spawned trees keep their generated stage", staged_trees.size() >= 2, str(staged_trees.keys()))
	_check("sprite textures match the growth stage", visuals_match)

	main.queue_free()
	await process_frame


func _texture_for_stage(tree, stage: int) -> Texture2D:
	match stage:
		TreeEntity.TreeStage.SEEDLING:
			return tree.seedling_texture
		TreeEntity.TreeStage.YOUNG:
			return tree.young_texture
		TreeEntity.TreeStage.STUMP:
			return tree.stump_texture
		_:
			return tree.mature_texture
