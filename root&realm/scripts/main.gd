extends Node2D

const WORLD_SEED := 12345

var world_generator := WorldGenerator.new()
var world: WorldGrid
var world_renderer: WorldRenderer
var minimap: Minimap
var clock := GameClock.new()
var clock_hud: ClockHud
# The building armed for placement, or "" when the pointer is not placing.
var placement_id := ""
var ghost: PlacementGhost

@onready var camera: CameraController = $Camera2D


func _ready() -> void:
	_setup_camera()

	world_renderer = WorldRenderer.new()
	add_child(world_renderer)

	world = world_generator.generate_world(WORLD_SEED)
	world_renderer.display_world(world)
	_setup_hud(world)
	_setup_placement()
	_place_starting_camp()


func _process(delta: float) -> void:
	# The clock is the only thing that owns time; systems will hang off its
	# ticks, never off this delta. World animation is retimed to the speed so
	# nothing moves at its own pace while the simulation is paused or at 4x.
	clock.advance(delta)
	world_renderer.set_time_scale(clock.speed_scale())

	# The camera can pan under a still pointer, so the preview follows the mouse
	# every frame rather than only when the mouse moves.
	if placement_id != "":
		set_pointer(get_global_mouse_position())


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


func _setup_placement() -> void:
	ghost = PlacementGhost.new()
	ghost.name = "PlacementGhost"
	# Above the y-sorted props: a preview behind a tree would be unreadable.
	ghost.z_index = 100
	ghost.visible = false
	add_child(ghost)


func _place_starting_camp() -> void:
	## The camp founds the settlement in the generator's clearing, so it is the
	## one building nobody places by hand.
	var tile := Vector2i.ONE * (WorldGenerator.MAP_SIZE / 2)
	var id := _add_building("camp", tile)

	if id < 0:
		push_warning("Main: the clearing centre could not hold the camp")


func _add_building(id: String, tile: Vector2i) -> int:
	_clear_cover(Placement.footprint_tiles(id, tile))

	var building_id := world.add_building(id, tile, BuildingDefs.get_def(id)["size"])

	world_renderer.spawn_object(building_id)
	minimap.refresh()

	return building_id


func _clear_cover(tiles: Array[Vector2i]) -> void:
	## A building flattens the tufts and flowers it stands on: they never block
	## it, so they must not keep poking through its floor.
	for tile in tiles:
		for object_id in world.objects_by_tile.get(tile, []).duplicate():
			if Placement.blocks_building(world.objects_by_id.get(object_id, {})):
				continue

			world.remove_object(object_id)
			world_renderer.remove_object(object_id)


func begin_placement(id: String) -> void:
	## Arms a building: the ghost then follows the pointer until it is cancelled.
	if BuildingDefs.get_def(id).is_empty():
		return

	placement_id = id
	ghost.visible = true
	set_pointer(get_global_mouse_position())


func cycle_placement() -> void:
	## There is no build menu yet, so one key walks the roster in order; the menu
	## will arm the same mode.
	var ids := BuildingDefs.ids()

	begin_placement(ids[(ids.find(placement_id) + 1) % ids.size()])


func cancel_placement() -> void:
	placement_id = ""
	ghost.visible = false


func set_pointer(world_point: Vector2) -> void:
	## Moves the preview to the tile under a world point. Argument-driven, so the
	## placement path can be tested without a real pointer.
	if placement_id == "":
		return

	ghost.update(
		world,
		placement_id,
		Vector2i(
			floori(world_point.x / WorldRenderer.TILE_SIZE),
			floori(world_point.y / WorldRenderer.TILE_SIZE)
		)
	)


func try_commit() -> int:
	## Places the armed building where the ghost stands and returns its id, or -1
	## when the tiles refuse it. Placement stays armed: a village is many
	## buildings, and cancelling is explicit.
	if placement_id == "" or ghost.reason != Placement.Reason.OK:
		return -1

	return _add_building(placement_id, ghost.tile)


func _setup_camera() -> void:
	var world_size := WorldGenerator.MAP_SIZE * WorldRenderer.TILE_SIZE

	camera.position = Vector2.ONE * world_size / 2.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = world_size
	camera.limit_bottom = world_size
	camera.reset_smoothing()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey

	if key != null:
		if not key.pressed or key.echo:
			return

		if key.keycode == KEY_B:
			cycle_placement()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_ESCAPE and placement_id != "":
			cancel_placement()
			get_viewport().set_input_as_handled()

		return

	if placement_id == "":
		return

	var button := event as InputEventMouseButton

	if button == null or not button.pressed:
		return

	if button.button_index == MOUSE_BUTTON_LEFT:
		set_pointer(get_global_mouse_position())
		try_commit()
		get_viewport().set_input_as_handled()
	elif button.button_index == MOUSE_BUTTON_RIGHT:
		cancel_placement()
		get_viewport().set_input_as_handled()
