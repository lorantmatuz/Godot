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
- `scripts/` — one script per scene plus `world_generator.gd` and
  `world_renderer.gd`.
- `assets/` — sprite sheets and the atlas resources cut from them.
- `tests/` — headless smoke tests.

## Tests

```sh
godot --headless --path "root&realm" --script res://tests/smoke_test.gd
```

The smoke test covers generation determinism, object placement, tree growth
stages, and camera setup. It exits non-zero on failure.

## Notes

- The world is 64×64 tiles of 64 px; the camera starts in the middle of the
  starting clearing.
- Generation is deterministic: `WORLD_SEED` in `scripts/main.gd` fixes the map.
- Commit a sheet's `.import` file together with the PNG.
