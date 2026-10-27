# Root & Realm

A small 2D top-down settlement builder in a procedurally generated forest.
The world generation, rendering, and camera are in place; the economy, workers,
and buildings are still to come. See [`design.md`](design.md) for the design and
[`todo.md`](todo.md) for the current plan.

## Running

Open `project.godot` in Godot 4.7 or newer and press F5.

From the repository root:

```sh
godot --headless --path "root&realm" --quit-after 300
```

Quote the project folder in the shell: `&` is a control operator and would
otherwise start a background job.

## Controls

- W/A/S/D or arrow keys — pan the camera
- `=` / `-` — zoom in / out

The camera is clamped to the map, so it cannot pan into the void. Mouse-wheel
zoom and drag-pan are not implemented yet.

## Structure

- `scenes/levels/main.tscn` — main scene; camera and world setup live here.
- `scenes/` — reusable entity scenes (`tree`, `rock`, `grass`).
- `scripts/` — one script per scene plus the world pipeline:
  `world_grid.gd` (terrain + object data), `world_generator.gd` (noise and
  placement rules), and `world_renderer.gd` (TileMapLayer ground, decals,
  y-sorted objects).
- `assets/` — sprite sheets and the atlas resources cut from them.
- `tests/` — headless smoke tests.

## World generation

- Terrain is semantic (`water`, `grass`, `forest floor`, `rocky`), shaped by
  seeded elevation and moisture noise instead of per-tile colour noise.
- Trees cluster on forest floor and open grass, stones sit on rocky ground.
- A starting clearing is kept free, and a grove plus an outcrop are guaranteed
  within reach of the start.
- Ground is drawn through a `TileMapLayer` with a runtime-generated `TileSet`
  (grass variants, autoshaded water edges, rock, forest floor). Trees and rocks
  stay separate y-sorted scenes so they can grow, be selected, and be harvested.

## Tests

```sh
godot --headless --path "root&realm" --script res://tests/smoke_test.gd
```

The smoke test covers generation determinism, terrain and resource placement,
tree growth stages, camera setup, tilemap coverage, and rebuilding the world.
It exits non-zero on failure.

## Notes

- The world is 64×64 tiles of 64 px; the camera starts in the middle of the
  starting clearing.
- Generation is deterministic: `WORLD_SEED` in `scripts/main.gd` fixes the map.
- Commit a sheet's `.import` file together with the PNG.
