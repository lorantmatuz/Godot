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
  placement rules), and `world_renderer.gd` (shader ground, decals, y-sorted
  objects).
- `shaders/ground.gdshader` — per-pixel ground colour.
- `assets/` — sprite sheets and the atlas resources cut from them.
- `tests/` — headless smoke tests.

## World generation

- Terrain is semantic (`water`, `grass`, `forest floor`, `rocky`), shaped by
  seeded elevation and moisture noise instead of per-tile colour noise.
- Objects are scattered by terrain density: forest floor keeps 20 % trees,
  grass 1.2 %, rocky ground 50 % stones, so woods are dense and meadows open.
  Stones sit on rocky ground.
- A starting clearing is kept free, and a grove plus an outcrop are guaranteed
  within reach of the start.
- Ground is a shader, not a tilemap. For every pixel it blends the four
  neighbouring terrain tiles, offsets the lookup by a seeded noise jitter, and
  blends water through shallow water and a sand band before the land colour.
  Terrain edges therefore never line up with the 64 px tile grid and stay
  smooth at any zoom, at the cost of one small terrain texture. Trees and
  rocks stay separate y-sorted scenes so they can grow, be selected, and be
  harvested.

### Ground tuning

The ground look is tuned in `scripts/world_renderer.gd`; the shader only
applies it. Band values are in land share units, where one tile of ground
is `1.0`.

| Constant | Default | Effect |
|---|---|---|
| `JITTER` | `12.0` | coastline and border wobble, in pixels |
| `LAND_SHARPNESS` | `16.0` | width of every land ↔ land border; higher is crisper |
| `ROCK_RIM_WIDTH` | `0.8` | thickness of the gravel rim around rock (sharpened share units) |
| `ROCK_RIM_STRENGTH` | `0.7` | how dark that rim reads, `0` disables it |
| `SHORE_SHALLOW` | `(0.0, 0.3)` | water → shallow band |
| `SHORE_SAND` | `(0.3, 0.48)` | shallow → sand band |
| `SHORE_LAND` | `(0.48, 0.68)` | sand → land colour |
| `GRASS_COLOR` … `ROCK_RIM_COLOR` | | palette |

## Tests

```sh
godot --headless --path "root&realm" --script res://tests/smoke_test.gd
```

The smoke test covers generation determinism, terrain and resource placement,
tree growth stages, camera setup, ground texture setup, and rebuilding the
world. It exits non-zero on failure.

## Notes

- The world is 64×64 tiles of 64 px; the camera starts in the middle of the
  starting clearing.
- Generation is deterministic: `WORLD_SEED` in `scripts/main.gd` fixes the map.
- Commit a sheet's `.import` file together with the PNG.
