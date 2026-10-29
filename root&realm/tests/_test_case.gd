extends SceneTree

# Shared harness for the per-theme headless tests. CI runs every other *.gd in
# this folder as its own process; files starting with "_" are support code.
#
# Run one: godot --headless --path "root&realm" --script res://tests/test_minimap.gd

const WORLD_SEED := 12345
const TILE_SIZE := 32
const MAP_SIZE := 64

var failures := 0


func _initialize() -> void:
	run()


func run() -> void:
	# Overridden by each test; may await frames.
	pass


func check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		failures += 1
	print(("  ok   " if ok else "  FAIL ") + label + ("  [" + detail + "]" if detail != "" else ""))


func finish() -> void:
	print("smoke test: ", "FAIL (%d)" % failures if failures > 0 else "PASS")
	quit(1 if failures > 0 else 0)
