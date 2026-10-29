extends "res://tests/_test_case.gd"

# Object id -> node mapping, rect picking and removal.


func run() -> void:
	print("picking")
	var scene: PackedScene = load("res://scenes/levels/main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame

	var renderer = main.world_renderer
	var world: WorldGrid = renderer.world
	var nodes_match := true

	for i in range(world.objects.size()):
		if renderer.object_nodes.get(world.objects[i]["id"]) != renderer.object_layer.get_child(i):
			nodes_match = false

	check("every object id maps to its spawned node", nodes_match)
	check(
		"the node map covers every spawned object",
		renderer.object_nodes.size() == renderer.object_layer.get_child_count(),
		"%d ids / %d nodes" % [
			renderer.object_nodes.size(), renderer.object_layer.get_child_count()
		]
	)

	var agrees := true
	var hits := 0

	for i in range(0, 3900, 97):
		var point := Vector2((i % 61) * TILE_SIZE + 16.5, (i / 61) * TILE_SIZE + 16.5)
		var picked: int = renderer.pick(point)

		if picked != -1:
			hits += 1
		if picked != _expected_pick(renderer, point):
			agrees = false

	check(
		"picking matches a brute-force hit test over the whole map",
		agrees and hits > 0,
		"%d hits in 41 samples" % hits
	)
	check("picking outside the map finds nothing", renderer.pick(Vector2(-100.0, -100.0)) == -1)

	var target := _click_target(renderer)
	check("some object is clickable on its own sprite", not target.is_empty())

	if not target.is_empty():
		var target_node: Node = renderer.object_nodes[target["id"]]

		check(
			"a click returns the object id",
			renderer.pick(target["point"]) == target["id"],
			"id %d" % target["id"]
		)
		world.remove_object(target["id"])
		check("removing an object frees its node", renderer.remove_object(target["id"]))
		check("removing an unknown object frees nothing", not renderer.remove_object(-1))
		await process_frame
		check("the freed node is gone", not is_instance_valid(target_node))
		check(
			"data and nodes stay the same size after a removal",
			renderer.object_nodes.size() == world.objects.size()
			and renderer.object_layer.get_child_count() == world.objects.size()
		)
		check(
			"the removed object can no longer be clicked",
			renderer.pick(target["point"]) != target["id"]
		)

	main.queue_free()
	await process_frame
	finish()


func _click_target(renderer) -> Dictionary:
	## An object whose sprite centre resolves to itself: a clean click target.
	for obj in renderer.world.objects:
		var node: Node2D = renderer.object_nodes.get(obj["id"])

		if node == null:
			continue

		var point := _pick_rect(node).get_center()

		if _expected_pick(renderer, point) == obj["id"]:
			return {"id": obj["id"], "point": point}

	return {}


func _expected_pick(renderer, point: Vector2) -> int:
	## Brute-force hit test over every object, independent of the renderer's
	## tile window, so the pick reaches are validated too.
	var best := -1
	var best_foot := -INF

	for obj in renderer.world.objects:
		var node: Node2D = renderer.object_nodes.get(obj["id"])

		if node == null or node.position.y < best_foot:
			continue
		if is_equal_approx(node.position.y, best_foot) and obj["id"] < best:
			continue
		if not _pick_rect(node).has_point(point):
			continue

		best = obj["id"]
		best_foot = node.position.y

	return best


func _pick_rect(node: Node2D) -> Rect2:
	# Mirrors the kit's anchoring: the node sits at the foot and the canvas is
	# drawn upwards from (-w/2, -h).
	var sprite := node as Sprite2D

	if sprite == null:
		sprite = node.get_node_or_null("Sprite2D") as Sprite2D

	if sprite == null or sprite.texture == null:
		return Rect2()

	var sprite_size := sprite.texture.get_size()

	return Rect2(node.position + Vector2(-sprite_size.x / 2.0, -sprite_size.y), sprite_size)
