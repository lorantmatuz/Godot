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
- `scenes/` — reusable entity scenes (`tree`, `rock`, `grass`). `rock_group` is
  a hand-built five-rock cluster kept for reference; generation does not place
  it, because tiling it left bare ground between the blocks.
- `scripts/` — one script per scene plus the world pipeline:
  `world_grid.gd` (terrain, patch and object data), `world_generator.gd`
  (noise and placement rules), and `world_renderer.gd` (shader ground,
  y-sorted objects).
- `shaders/ground.gdshader` — per-pixel ground colour.
- `assets/` — sprite sheets and the atlas resources cut from them.
- `tests/` — headless smoke tests.

## World generation

- Terrain is semantic (`water`, `grass`, `forest floor`, `rocky`), shaped by
  seeded elevation and moisture noise instead of per-tile colour noise.
- Trees are scattered by terrain density: forest floor keeps 20 % trees,
  grass 1.2 % trees, so woods are dense and meadows open, and a tree may
  stand on its own.
- Meadows and quarries are placed as whole units. A meadow covers a disc of
  2.6–4.2 tiles on grass, plants 5 tufts per covered tile, and thins towards
  the rim.
- A quarry is one packed field of 10–100 stones, not a grid of separate piles.
  Stones are laid on a jittered lattice finer than a rock (0.3 tiles), and the
  field keeps the points nearest its centre, so stones overlap their
  neighbours and no bare ground opens up inside the mass. The rim gets a
  random rank wobble, so a quarry does not end in a clean grid or circle.
  A patch of fewer than 30 tufts or 10 stones is dropped entirely instead of
  leaving a few strays, and patches keep a gap from each other and never reach
  into the starting clearing. The result reads as one worked field, not
  scattered props.
- Every patch is recorded in `world.patches`, and each of its objects carries
  the patch index, its tile and an offset within that tile, so the unit can
  later be claimed, worked, or depleted as a whole. Tufts pick one of the four
  sprites in `assets/grass/` and stones one of five in `assets/rocks/`, each
  mirrored at random, so a field mixes shapes without showing its pitch.
- A starting clearing is kept free, and a grove, a quarry and a meadow are
  guaranteed within reach of the start.
- Ground is a shader, not a tilemap. For every pixel it blends the four
  neighbouring terrain tiles, offsets the lookup by a seeded noise jitter, and
  blends water through shallow water and a sand band before the land colour.
  Terrain edges therefore never line up with the 64 px tile grid and stay
  smooth at any zoom, at the cost of one small terrain texture. Trees, tufts
  and stones stay separate y-sorted scenes so they can grow, be selected, and
  be harvested.

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

The smoke test covers generation determinism, terrain and resource placement
(meadows and quarries are dense fields on their own ground, within reach of
the start), tree growth stages, camera setup, ground texture setup, and
rebuilding the world. It exits non-zero on failure.

## Notes

- The world is 64×64 tiles of 64 px; the camera starts in the middle of the
  starting clearing.
- Generation is deterministic: `WORLD_SEED` in `scripts/main.gd` fixes the map.
- Commit a sheet's `.import` file together with the PNG.
