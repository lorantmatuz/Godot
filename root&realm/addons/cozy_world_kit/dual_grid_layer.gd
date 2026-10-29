@tool
class_name DualGridLayer
extends TileMapLayer
## Dual-grid display layer for the kit's 16-tile corner sets (and the 25-tile cliff sets).
##
## Paint the terrain on the `world` layer (any tile = "upper" terrain: dirt, water, plateau ...).
## This layer sits half a tile up-left of it and draws, for every display cell, the atlas tile whose four
## corners match the four world cells around it (NW NE SE SW). The atlas comes from the kit's
## terrain/atlas/<set>.json (corner code -> atlas coords). Redraws when the world layer's painted cells change
## (checked every `poll_seconds`, in the editor and in game).
##
## Cliff mode (cliff_grass / cliff_rock): world cells = plateau. Corner labels: u = plateau cell,
## t = the cell directly below a plateau cell (cliff face), l = everything else.

@export var world: TileMapLayer:
	set(v):
		if world and world.changed.is_connected(_queue_rebuild):
			world.changed.disconnect(_queue_rebuild)
		world = v
		if world:
			world.changed.connect(_queue_rebuild)
		_queue_rebuild()
@export_file("*.json") var atlas_json := "":
	set(v):
		atlas_json = v
		_codes.clear()
		_queue_rebuild()
@export var cliff_mode := false:
	set(v):
		cliff_mode = v
		_queue_rebuild()
## Corner codes left empty so the layer below shows (llll = all lower terrain).
@export var skip_codes := PackedStringArray(["llll"]):
	set(v):
		skip_codes = v
		_queue_rebuild()
## Hide the world (paint) layer while the game runs.
@export var hide_world_in_game := true
## Watch the world layer for edits (editor painting, cells changed by game code). 0 = only on load / rebuild().
@export var poll_seconds := 0.1

signal rebuilt  ## after every redraw (WaterGlints listens to it)

var _codes := {}  # corner code -> Array[Vector2i] (several entries = random variants)
var _pending := false
var _sig := 0
var _t := 0.0


func _ready() -> void:
	if world and hide_world_in_game and not Engine.is_editor_hint():
		world.visible = false
	rebuild()


func _process(delta: float) -> void:
	# TileMapLayer.changed is not emitted for set_cell in Godot 4.4, so edits are found by comparing the painted cells
	if world == null or poll_seconds <= 0.0:
		return
	_t += delta
	if _t < poll_seconds:
		return
	_t = 0.0
	if hash(world.get_used_cells()) != _sig:
		rebuild()


func _queue_rebuild() -> void:
	if _pending or not is_inside_tree():
		return
	_pending = true
	rebuild.call_deferred()


func _load_codes() -> void:
	var meta = JSON.parse_string(FileAccess.get_file_as_string(atlas_json))
	if meta == null:
		push_warning("DualGridLayer: cannot read %s" % atlas_json)
		return
	for code in meta.tiles:
		var list: Array[Vector2i] = []
		for xy in meta.tiles[code]:
			list.append(Vector2i(xy[0], xy[1]))
		_codes[code] = list


## First atlas coords for a corner code (e.g. "uuuu" = the full upper-terrain tile).
func code_coords(code: String) -> Vector2i:
	if _codes.is_empty():
		_load_codes()
	return _codes[code][0] if _codes.has(code) else Vector2i(-1, -1)


func _label(used: Dictionary, c: Vector2i) -> String:
	if used.has(c):
		return "u"
	if cliff_mode and used.has(c + Vector2i.UP):
		return "t"
	return "l"


func rebuild() -> void:
	_pending = false
	clear()
	if world == null or atlas_json == "" or tile_set == null:
		return
	if _codes.is_empty():
		_load_codes()
	var half := Vector2(tile_set.tile_size) / 2.0
	position = world.position - half
	var cells := world.get_used_cells()
	_sig = hash(cells)
	var used := {}
	for c in cells:
		used[c] = true
	if used.is_empty():
		rebuilt.emit()
		return
	var r := world.get_used_rect()
	var missing := {}
	for j in range(r.position.y, r.end.y + 2):
		for i in range(r.position.x, r.end.x + 2):
			var nw := Vector2i(i - 1, j - 1)
			var code := _label(used, nw) + _label(used, Vector2i(i, j - 1)) + _label(used, Vector2i(i, j)) + _label(used, Vector2i(i - 1, j))
			if code in skip_codes:
				continue
			if not _codes.has(code):
				missing[code] = true
				continue
			var options: Array = _codes[code]
			set_cell(Vector2i(i, j), 0, options[posmod(nw.x * 7 + nw.y * 13, options.size())])  # stable variant per cell
	rebuilt.emit()
	if not missing.is_empty():
		push_warning("DualGridLayer %s: no tile for corner codes %s (cliff sets: keep the plateau's south edge from stepping by exactly one tile)" % [name, missing.keys()])
