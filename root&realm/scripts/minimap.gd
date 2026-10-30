extends Control
class_name Minimap

## A minimap built from WorldGrid data, not a second viewport: one image pixel
## per tile plus a live rect for the camera view. Click or drag to move the
## camera. The image is cheap to rebuild (64x64 pixels), so callers refresh it
## after the world changes; the view rect follows the camera every frame.

const PIXELS_PER_TILE := 2
# A chunky wooden frame: dark outline, a lit top-left bevel, five pixels of
# wood, and a dark line so the map art never touches it.
const BORDER := 8

# Sampled from the kit art (the fill's grass, the atlases' full-dirt and
# full-water tiles), so the minimap reads like the map and not like a legend.
const TERRAIN_COLORS := {
	WorldGrid.Terrain.GRASS: Color("73a85c"),
	WorldGrid.Terrain.SOIL: Color("aa7c56"),
	WorldGrid.Terrain.WATER: Color("6ebfed"),
}

# Canopy colours from the kit sprites: a cherry grove has to read pink, a pine
# dark green, a willow pale green.
const TREE_SPECIES_COLORS := {
	"oak": Color("628742"),
	"pine": Color("466a36"),
	"cherry": Color("e3a2b8"),
	"willow": Color("83a650"),
}
const TREE_STAGE_COLORS := {
	TreeEntity.TreeStage.SEEDLING: Color("65934a"),
	TreeEntity.TreeStage.YOUNG: Color("498048"),
	TreeEntity.TreeStage.STUMP: Color("926445"),
}

# Objects smaller than a tile tint the ground they stand on instead of replacing
# it, so the terrain still reads. Several on one tile pull it further, which is
# what makes a planted field look greener than bare soil.
const SMALL_OBJECT_TINT := 0.6

# Main colour of each kit prop (the sprite's dominant colour; flower patches use
# their bloom). Must cover WorldRenderer.PROP_TEXTURES; tufts share it.
const PROP_COLORS := {
	"tall_grass_tuft": Color("83a650"),
	"small_round_bush": Color("384d32"),
	"berry_bush": Color("384d32"),
	"rose_bush": Color("384d32"),
	"blue_flowers_patch": Color("034b89"),
	"yellow_flowers_patch": Color("edd192"),
	"red_mushrooms": Color("a91e1e"),
	"small_rocks_cluster": Color("9f9c8d"),
	"mossy_rock": Color("434345"),
	"lily_pads_lotus": Color("83a650"),
	"cattail_reeds_bank": Color("83a650"),
	"small_wooden_rowboat_floating": Color("aa7c56"),
}

# Kit wood, straight from the fence and signpost sprites.
const FRAME_WOOD := Color("6e4e36")
const FRAME_LIGHT := Color("926445")
const FRAME_SHADE := Color("664031")
const FRAME_DARK := Color("030101")
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
	custom_minimum_size = map_rect().end + Vector2.ONE * BORDER
	size = custom_minimum_size
	refresh()


func map_rect() -> Rect2:
	## The map art, in this control's coordinates.
	return Rect2(Vector2.ONE * BORDER, Vector2(world.size * PIXELS_PER_TILE))


func tree_color(stage: int, species: String) -> Color:
	## Mature trees show their canopy, younger ones and stumps their own tint.
	if stage == TreeEntity.TreeStage.MATURE:
		return TREE_SPECIES_COLORS.get(species, TREE_SPECIES_COLORS["oak"])

	return TREE_STAGE_COLORS.get(stage, TREE_STAGE_COLORS[TreeEntity.TreeStage.SEEDLING])


func object_color(obj: Dictionary) -> Color:
	## What an object contributes to its tile: a tree's canopy or a prop's own
	## colour.
	if obj["type"] == "tree":
		return tree_color(obj["stage"], obj.get("species", ""))

	return PROP_COLORS.get(obj["name"], TERRAIN_COLORS[WorldGrid.Terrain.GRASS])


func refresh() -> void:
	## Redraws the map image from the world data. Cheap enough for every change.
	_image = Image.create(world.size.x, world.size.y, false, Image.FORMAT_RGBA8)

	for y in range(world.size.y):
		for x in range(world.size.x):
			_image.set_pixel(x, y, TERRAIN_COLORS[world.get_terrain(x, y)])

	# Objects go over the ground they stand on, in world order.
	for obj in world.objects:
		var tile := Vector2i(obj["x"], obj["y"])
		var color := object_color(obj)

		if obj["type"] == "tree":
			_image.set_pixel(tile.x, tile.y, color)
		else:
			_image.set_pixel(
				tile.x, tile.y, _image.get_pixel(tile.x, tile.y).lerp(color, SMALL_OBJECT_TINT)
			)

	_texture = ImageTexture.create_from_image(_image)
	_view = view_rect()
	queue_redraw()


func view_rect() -> Rect2:
	## The camera's view, in this control's coordinates, clamped to the map.
	var half := get_viewport_rect().size / camera.zoom / 2.0
	var map := Rect2(Vector2.ZERO, Vector2(world.size * WorldRenderer.TILE_SIZE))
	var seen := Rect2(camera.position - half, half * 2.0).intersection(map)

	return Rect2(
		map_rect().position + seen.position / WorldRenderer.TILE_SIZE * PIXELS_PER_TILE,
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
	# Only the map itself moves the camera; the frame is not a place on it.
	var map := map_rect()

	if not map.has_point(point):
		return

	camera.focus_on(
		(point - map.position) / PIXELS_PER_TILE * WorldRenderer.TILE_SIZE
		+ Vector2.ONE * WorldRenderer.TILE_SIZE / 2.0
	)


func _draw() -> void:
	if _texture == null:
		return

	_draw_frame()
	draw_texture_rect(_texture, map_rect(), false)
	draw_rect(_view, VIEW_COLOR, false, 1.0)


func _draw_frame() -> void:
	var full := Rect2(Vector2.ZERO, size)
	var inner := Rect2(Vector2.ONE, full.size - Vector2.ONE * 2.0)

	# A soft drop shadow sells the frame as a panel lying on the HUD.
	draw_rect(Rect2(full.position + Vector2(2.0, 2.0), full.size), Color(0.0, 0.0, 0.0, 0.3))
	draw_rect(full, FRAME_DARK)
	draw_rect(full.grow(-1.0), FRAME_WOOD)
	# Raised bevel: the top and left edges catch the light, the other two do not.
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1.0)), FRAME_LIGHT)
	draw_rect(Rect2(inner.position, Vector2(1.0, inner.size.y)), FRAME_LIGHT)
	draw_rect(Rect2(inner.position + Vector2(0.0, inner.size.y - 1.0), Vector2(inner.size.x, 1.0)), FRAME_SHADE)
	draw_rect(Rect2(inner.position + Vector2(inner.size.x - 1.0, 0.0), Vector2(1.0, inner.size.y)), FRAME_SHADE)
	# The inner line is drawn over the wood, so the map starts one pixel later.
	draw_rect(full.grow(1.0 - BORDER), FRAME_DARK)
