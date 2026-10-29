@tool
class_name WaterGlints
extends Node2D
## Animated glints on open water — the kit's water tiles are one flat colour, this node adds the shimmer.
## Point `water` at the water DualGridLayer (the display layer). Glints go only on pixels of the flat water
## colour whose neighbours 3 px away are water too (banks, shores and reeds stay clear).
## 6-frame glint, 16-frame loop, random phase per glint.

@export var water: DualGridLayer:
	set(v):
		if water and water.rebuilt.is_connected(_queue_scatter):
			water.rebuilt.disconnect(_queue_scatter)
		water = v
		if water:
			water.rebuilt.connect(_queue_scatter)
		_queue_scatter()
@export var frame_ms := 110
@export var glint_seed := 11
## One glint per this many open-water pixels (the kit demo uses 150).
@export var pixels_per_glint := 150.0
@export var playing := true

const FRAMES := 16
const LIGHT := Color8(176, 222, 247)
const MID := Color8(86, 173, 224)
const PEAK := Color8(236, 248, 253)
# one glint's life, one shape per frame (dx, dy, colour): swell -> peak -> fade along a short wave line
var SHAPES := [
	[[0, 0, MID]],
	[[-1, 0, LIGHT], [0, 0, LIGHT], [1, 0, LIGHT]],
	[[-2, 0, LIGHT], [-1, 0, LIGHT], [0, 0, PEAK], [1, 0, LIGHT], [2, 0, LIGHT], [0, -1, LIGHT]],
	[[-2, 0, LIGHT], [-1, 0, LIGHT], [0, 0, LIGHT], [1, 0, LIGHT], [2, 0, LIGHT]],
	[[-1, 0, MID], [0, 0, MID], [1, 0, MID]],
	[[-2, 0, MID], [2, 0, MID]],
]

var frame := 0
var _glints := []  # [Vector2i position, phase]
var _t := 0.0
var _pending := false


func _ready() -> void:
	scatter()


func _queue_scatter() -> void:
	if _pending or not is_inside_tree():
		return
	_pending = true
	scatter.call_deferred()


func scatter() -> void:
	_pending = false
	_glints.clear()
	queue_redraw()
	if water == null or water.tile_set == null or water.get_used_cells().is_empty():
		return
	var src := water.tile_set.get_source(0) as TileSetAtlasSource
	var img := src.texture.get_image()
	if img.is_compressed():
		img.decompress()
	var ts := water.tile_set.tile_size
	var full := water.code_coords("uuuu") * ts
	var flat := img.get_pixel(full.x + ts.x / 2, full.y + ts.y / 2)
	var r := water.get_used_rect()
	var w := r.size.x * ts.x
	var h := r.size.y * ts.y
	var wet := PackedByteArray()
	wet.resize(w * h)
	for c in water.get_used_cells():
		var a := water.get_cell_atlas_coords(c) * ts
		var o := (c - r.position) * ts
		for y in ts.y:
			for x in ts.x:
				if img.get_pixel(a.x + x, a.y + y) == flat:
					wet[(o.y + y) * w + o.x + x] = 1
	var origin := Vector2i(water.position) + r.position * ts
	var points: Array[Vector2i] = []
	# Only water pixels can carry a glint, so walk the painted cells instead of
	# the whole bounding box. Ponds spread across a 64x64 map make that box as
	# big as the map, which turned this loop into a multi-second startup scan.
	for c in water.get_used_cells():
		var o := (c - r.position) * ts
		for y in ts.y:
			for x in ts.x:
				var px := o.x + x
				var py := o.y + y
				# A glint needs water 3 px around it, so box borders never qualify.
				if px < 3 or py < 3 or px >= w - 3 or py >= h - 3:
					continue
				var ok := true
				for dy in [-3, 0, 3]:
					for dx in [-3, 0, 3]:
						if wet[(py + dy) * w + px + dx] == 0:
							ok = false
				if ok:
					points.append(origin + Vector2i(px, py))
	var rng := RandomNumberGenerator.new()
	rng.seed = glint_seed
	for k in range(points.size() - 1, 0, -1):  # shuffle, then keep glints ≥ 8 px apart
		var m := rng.randi_range(0, k)
		var tmp := points[k]
		points[k] = points[m]
		points[m] = tmp
	var cap := int(points.size() / pixels_per_glint)
	for p in points:
		if _glints.size() >= cap:
			break
		var ok := true
		for g in _glints:
			if abs(p.x - g[0].x) <= 7 and abs(p.y - g[0].y) <= 7:
				ok = false
				break
		if ok:
			_glints.append([p, rng.randi_range(0, FRAMES - 1)])
	queue_redraw()


func _process(delta: float) -> void:
	if not playing:
		return
	_t += delta
	if _t >= frame_ms / 1000.0:
		_t = fmod(_t, frame_ms / 1000.0)
		frame = (frame + 1) % FRAMES
		queue_redraw()


func _draw() -> void:
	for g in _glints:
		var age := posmod(frame - g[1], FRAMES)
		if age < SHAPES.size():
			for px in SHAPES[age]:
				draw_rect(Rect2(g[0].x + px[0], g[0].y + px[1], 1, 1), px[2])
