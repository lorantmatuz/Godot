extends Control
class_name Minimap

## A minimap built from WorldGrid data, not a second viewport: one image pixel
## per tile plus a live rect for the camera view. Click or drag to move the
## camera. The image is cheap to rebuild (64x64 pixels), so callers refresh it
## after the world changes; the view rect follows the camera every frame.

const PIXELS_PER_TILE := 2

# Sampled from assets/cozy_world_kit/palette/palette.hex so the minimap reads as
# the same world.
const TERRAIN_COLORS := {
	WorldGrid.Terrain.GRASS: Color("35673d"),
	WorldGrid.Terrain.SOIL: Color("6e4e36"),
	WorldGrid.Terrain.WATER: Color("0f6bab"),
}
const TREE_COLOR := Color("233c1d")
const VIEW_COLOR := Color(1.0, 1.0, 1.0, 0.9)

var world: WorldGrid
var camera: CameraController

var _image: Image
var _texture: ImageTexture
var _view := Rect2()


func setup(new_world: WorldGrid, new_camera: CameraController) -> void:
	world = new_world
	camera = new_camera
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(world.size * PIXELS_PER_TILE)
	size = custom_minimum_size
	refresh()


func refresh() -> void:
	## Redraws the map image from the world data. Cheap enough for every change.
	_image = Image.create(world.size.x, world.size.y, false, Image.FORMAT_RGBA8)

	for y in range(world.size.y):
		for x in range(world.size.x):
			_image.set_pixel(x, y, TERRAIN_COLORS[world.get_terrain(x, y)])

	for obj in world.objects:
		if obj["type"] == "tree":
			_image.set_pixel(obj["x"], obj["y"], TREE_COLOR)

	_texture = ImageTexture.create_from_image(_image)
	_view = view_rect()
	queue_redraw()


func view_rect() -> Rect2:
	## The camera's view, in minimap pixels, clamped to the map.
	var half := get_viewport_rect().size / camera.zoom / 2.0
	var map := Rect2(Vector2.ZERO, Vector2(world.size * WorldRenderer.TILE_SIZE))
	var seen := Rect2(camera.position - half, half * 2.0).intersection(map)

	return Rect2(
		seen.position / WorldRenderer.TILE_SIZE * PIXELS_PER_TILE,
		seen.size / WorldRenderer.TILE_SIZE * PIXELS_PER_TILE
	)


func _process(_delta: float) -> void:
	var view := view_rect()

	if view != _view:
		_view = view
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_focus_at(event.position)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_focus_at(event.position)


func _focus_at(point: Vector2) -> void:
	# Centre the camera on the clicked tile; focus_on() keeps it inside the map.
	camera.focus_on((point / PIXELS_PER_TILE + Vector2(0.5, 0.5)) * WorldRenderer.TILE_SIZE)


func _draw() -> void:
	if _texture == null:
		return

	draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.5), false, 1.0)
	draw_rect(_view, VIEW_COLOR, false, 1.0)
