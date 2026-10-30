class_name PlacementGhost
extends Node2D

## The pale preview under the pointer while a building is armed: the kit prop at
## partial alpha, its footprint tinted green or red, and — when red — the reason
## printed under the frame.
##
## Everything is drawn in world coordinates, so the node itself stays at the
## origin: moving the preview is one integer tile, not a transform.

const GHOST_ALPHA := 0.55
const TILE_ALPHA := 0.3
const VALID_TINT := Color("9cf0a4")
const INVALID_TINT := Color("f08c7c")
const LABEL_SIZE := 10
const LABEL_PADDING := 3.0
const LABEL_COLOR := Color("f4e6c8")
const LABEL_BACKGROUND := Color(0.1, 0.08, 0.06, 0.8)

var building_id := ""
# Anchor tile, the footprint's top-left.
var tile := Vector2i.ZERO
var reason := Placement.Reason.UNKNOWN

var _def := {}
var _texture: Texture2D


func update(world: WorldGrid, id: String, anchor: Vector2i) -> void:
	building_id = id
	tile = anchor
	_def = BuildingDefs.get_def(id)
	_texture = _def.get("texture")
	reason = Placement.can_place(world, id, anchor)
	queue_redraw()


func footprint_rect() -> Rect2:
	var size: Vector2i = _def.get("size", Vector2i.ONE)

	return Rect2(Vector2(tile) * WorldRenderer.TILE_SIZE, Vector2(size) * WorldRenderer.TILE_SIZE)


func sprite_rect() -> Rect2:
	## Where the building itself would be drawn: kit props hang from their foot,
	## the bottom centre of the footprint.
	if _texture == null:
		return Rect2()

	var size: Vector2i = _def.get("size", Vector2i.ONE)
	var foot := Vector2(
		(tile.x + size.x / 2.0) * WorldRenderer.TILE_SIZE,
		(tile.y + size.y) * WorldRenderer.TILE_SIZE
	)

	return Rect2(
		foot - Vector2(_texture.get_width() / 2.0, _texture.get_height()), _texture.get_size()
	)


func _draw() -> void:
	if _texture == null:
		return

	var tint := VALID_TINT if reason == Placement.Reason.OK else INVALID_TINT

	for cell in Placement.footprint_tiles(building_id, tile):
		draw_rect(
			Rect2(Vector2(cell) * WorldRenderer.TILE_SIZE, Vector2.ONE * WorldRenderer.TILE_SIZE),
			Color(tint, TILE_ALPHA)
		)

	draw_rect(footprint_rect(), tint, false, 1.0)
	draw_texture_rect(_texture, sprite_rect(), false, Color(tint, GHOST_ALPHA))

	if reason != Placement.Reason.OK:
		_draw_reason(footprint_rect().end)


func _draw_reason(at: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var text := Placement.reason_text(reason)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	var box := Rect2(
		at + Vector2(0.0, 2.0),
		Vector2(width + LABEL_PADDING * 2.0, LABEL_SIZE + LABEL_PADDING * 2.0)
	)

	draw_rect(box, LABEL_BACKGROUND)
	draw_string(
		font,
		box.position + Vector2(LABEL_PADDING, LABEL_SIZE + LABEL_PADDING / 2.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		LABEL_SIZE,
		LABEL_COLOR
	)
