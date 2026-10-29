# Root & Realm

A small 2D top-down settlement builder in a procedurally generated landscape.
The world generation, rendering, and camera are in place; the economy, workers,
and buildings are still to come. See [`design.md`](design.md) for the design and
[`todo.md`](todo.md) for the current plan.

The art is the [Cozy World Kit](https://vibeforge.itch.io) (32 px top-down
village & nature set, free edition); see [Licensing](#licensing).

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
- cursor in a screen margin — pan the camera toward that edge
- click or drag the minimap (bottom-right) — move the camera there
- `=` / `-` — zoom in / out in whole steps (1×–4×, starts at 2×)

The camera is clamped to the map, so it cannot pan into the void. Mouse-wheel
zoom and drag-pan on the world are not implemented yet.

## Structure

- `scenes/levels/main.tscn` — main scene; camera and world setup live here.
- `scenes/tree.tscn` — tree entity (growth stage + species data).
- `scripts/` — one script per scene plus the world pipeline:
  `world_grid.gd` (terrain, grass variants, plot and object data),
  `world_generator.gd` (terrain painting and placement rules), and
  `world_renderer.gd` (fill layer, dual-grid blend layers, glints, y-sorted
  props).
- Every world object carries a stable `id`. `WorldGrid.objects_by_id` and
  `objects_by_tile` address it, and `WorldRenderer.object_nodes` maps it to the
  spawned node, so `remove_object(id)` deletes data and visual together.
  Clicking is a sprite-rect hit test (`WorldRenderer.pick(point)`); decor props
  deliberately have no `Area2D` or collision shape.
- `scripts/minimap.gd` — a HUD `Control` on a `CanvasLayer`: one image pixel per
  tile (2 px per tile on screen) coloured from terrain and trees, plus a live
  rect for the camera view; click or drag it to move the camera. It is built
  from `WorldGrid`, not a second viewport, so `refresh()` is the one call needed
  after the world changes.
- `addons/cozy_world_kit/` — the kit's `DualGridLayer` and `WaterGlints` nodes.
- `assets/cozy_world_kit/` — terrain atlases + their JSON corner maps, tilesets,
  props, palette and the kit's license.
- `tests/` — headless tests, one file per theme, with `_test_case.gd` as the
  shared harness (see [Tests](#tests)).
- `COZY_KIT_MIGRATION.md` — why the world looks the way it does, and what was
  removed.

## World generation

- The ground has three terrains: `grass`, `soil` and `water`. Grass is the base;
  soil is painted as the starting camp clearing, dirt trails and tilled field
  plots; water is painted as one to three ponds.
- Water always keeps a one-tile **grass bank**: the free kit has no soil ↔ water
  corner set, so two blend sets must never meet. Generation enforces the bank,
  which also reads as a natural shore.
- Trees grow only on grass, denser where the moisture noise is high, with a
  spacing rule so 64 px canopies keep a gap. Mature trees are one of four kit
  species (oak, pine, cherry, willow); seedlings and young trees use the kit's
  bush and small oak art, and stumps use the stump prop.
- Field plots are planted as whole units: a centre on grass clear of water, a
  disc of 2.6–4.2 tiles turned into tilled soil, and a light tuft scatter
  thinning towards the rim. A plot thinner than 10 tufts is dropped entirely,
  ground included. Plots keep a gap from each other and never reach into the
  starting clearing.
- Every plot is recorded in `world.patches`, and each of its tufts carries the
  plot index, its tile and an offset within that tile, so the plot can later be
  claimed, worked, or harvested as one thing.
- Low-density props (bushes, flowers, mushrooms, rocks) decorate the meadow;
  ponds get lily pads, reeds and the occasional rowboat on open water.
- A starting clearing is kept free, and a grove plus a field are guaranteed
  within reach of the start.

## Ground rendering

The ground is tile-based, not a shader:

- A `TileMapLayer` paints the 16-variant grass fill chosen by
  `WorldGrid.ground_variant`, so the base never has a visible repeat seam.
- Soil and water each get a hidden paint layer (`TileMapLayer`) with one cell per
  tile plus a `DualGridLayer` that draws the kit's 16 corner tiles from
  `terrain/atlas/grass_dirt.json` / `grass_water.json`.
- The display layer only draws blended corners (`llll`, pure grass, is skipped),
  so the fill shows through. Water glints are drawn at runtime by
  `WaterGlints` over open water.

Adding a new blend set later (the paid kit has 15 more) means shipping its atlas
PNG/JSON and tileset and pointing the renderer at it; no code rewrite.

### Generation tuning

The world look is tuned in `scripts/world_generator.gd`.

| Constant | Default | Effect |
|---|---|---|
| `POND_COUNT_MIN` / `POND_COUNT_MAX` | `1` / `3` | how many ponds a map gets |
| `POND_RADIUS_MIN` / `POND_RADIUS_MAX` | `2.6` / `5.0` | pond size, in tiles |
| `POND_EDGE_WOBBLE` | `0.9` | how ragged a pond outline is |
| `TRAIL_LENGTH_MIN` / `TRAIL_LENGTH_MAX` | `14` / `28` | dirt trail length |
| `TREE_DENSITY_MIN` / `TREE_DENSITY_MAX` | `0.01` / `0.22` | tree density at the dry / wet end of the moisture noise |
| `FIELD_CHANCE` | `0.006` | per-tile chance to start a plot |
| `FIELD_RADIUS_MIN` / `FIELD_RADIUS_MAX` | `2.6` / `4.2` | plot size, in tiles |
| `FIELD_TUFTS_PER_TILE` | `1.2` | tuft scatter on a plot |
| `DECOR_CHANCE` | `0.018` | meadow prop density |

## Tests

Each theme has its own headless test file, sharing `tests/_test_case.gd`:

```sh
for test in "root&realm"/tests/test_*.gd; do
  godot --headless --path "root&realm" --script "res://tests/$(basename "$test")"
done
```

Or one at a time, e.g. `--script res://tests/test_minimap.gd`. Every test exits
non-zero on failure.

| File | Covers |
|---|---|
| `test_world_generation.gd` | same-seed determinism, object ids and the id/tile indexes |
| `test_world_layout.gd` | grass/soil/water balance, water banks, forest stages, field plots |
| `test_renderer.gd` | grass fill, dual-grid corners, glints, spawned sprites, rebuild |
| `test_picking.gd` | id → node map, rect picking, object removal |
| `test_camera.gd` | zoom, edge scroll, map clamping, `focus_on` |
| `test_minimap.gd` | minimap image pixels, view rect, click-to-move, refresh |

## Notes

- The world is 64×64 tiles of 32 px; the camera starts at 2× in the middle of
  the starting clearing.
- Generation is deterministic: `WORLD_SEED` in `scripts/main.gd` fixes the map.
- Commit a PNG's `.import` file together with the PNG.
- `preview/` holds screenshots from the migration's visual pass.

## Licensing

The Cozy World Kit assets are licensed for personal and commercial use in games
and apps, but may not be resold or redistributed as standalone assets or inside
another asset pack, and may not be used to train AI models. The full license is
in [`assets/cozy_world_kit/LICENSE.txt`](assets/cozy_world_kit/LICENSE.txt).
All kit pixels were generated with PixelLab's tools (see that file's AI
disclosure).
