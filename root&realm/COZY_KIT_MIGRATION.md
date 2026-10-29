# Cozy World Kit migration plan

Replace the `Nature_MP` art and the shader ground with the **Cozy World Kit (32px,
free edition)**: grass/soil/water terrain drawn with the kit's dual-grid corner
tiles, kit props, and kit water glints.

Status: **implemented** 2026-10-29 (phases 1–7). Working tree already had
uncommitted changes to the files this touched; the migration built on that state.

QA during implementation changed two things:

- the noise erosion pass was dropped: it produced one- and two-tile dirt islands
  whose corner blends read as odd blobs. Soil now comes from the camp clearing,
  trails and field plots.
- pond props require open water around them (1 tile for lily pads, 2 for the
  rowboat) so a 64 px prop cannot hang over the bank.
- base grass excludes `variant_06` and `variant_14`: both are mostly a baked dirt
  patch, which reads as fake soil now that dirt is real terrain.
- the vendored `WaterGlints.scatter()` was patched to walk painted water cells
  instead of the pond bounding box. With ponds spread over the map the box is the
  whole map, and the scan cost 1.9 s at startup; it is ~0.2 s now. A 64×64 world
  builds in ~0.28 s total (fill + both blend layers + glints + 567 props).

## Decisions

| # | Decision | Why |
|---|---|---|
| D1 | Native **32 px** tiles; world is 64×64 tiles = 2048 px. Camera zoom ×2 (default 2, range 1–4), pan speed 500 → 250 | 1:1 kit pixels, no upscale blur; keeps today's on-screen framing and feel |
| D2 | **Grass is the base terrain**; soil and water are painted over it | Forced by the kit atlases: `l` (lower) is grass, `u` (upper) is dirt/water. The sets cannot draw grass over soil |
| D3 | Soil never touches water: every water tile gets a 1-tile grass bank | The free kit has no soil↔water set, so that seam cannot be drawn. A bank is also how the kit's demo pond reads |
| D4 | Fields are **soil plots** with sparse tufts; `world.patches` is kept | A tilled plot is the honest read; the 10-tufts-per-tile green carpet is retired. Alternative: grass interior with a 1-tile soil rim |
| D5 | Tree stages: seedling = `small_round_bush`, young = `round_leafy_oak_tree`, mature = oak/pine/cherry/willow chosen per tree, stump = `tree_stump` | The kit has no stage-per-species art; this keeps growth readable |
| D6 | Keep the two blend sets, but build the renderer data-driven so more atlases (full kit) are a drop-in | Avoids a second rewrite |

## Asset layout

```
assets/cozy_world_kit/
  LICENSE.txt, palette/
  terrain/atlas/{grass_dirt,grass_water}.png + .json
  tilesets/{fills_grass,grass_dirt,grass_water}.png/.tres
  props/props_32/*, props/props_64/*, water_64/*
addons/cozy_world_kit/{dual_grid_layer.gd, water_glints.gd, paint.png, world_paint.tres}
```

Removed: `assets/Nature_MP*.png` (+ `.import`), `assets/{grass,rocks,trees}/**.tres`,
`scenes/rock*.tscn`, `shaders/ground.gdshader`.

## Code changes

| File | Change |
|---|---|
| `scripts/world_grid.gd` | `Terrain { GRASS, SOIL, WATER }`; add `ground_variant: PackedByteArray` so the base grass variant is generated with the seed |
| `scripts/world_generator.gd` | Grass base; soil camp clearing; 1–3 seeded ponds with noise-wobbled outline; dirt trails from the clearing; **1-tile grass bank** around water; trees only on grass, moisture-driven, with spacing; field plots as soil discs with sparse tufts; low-density decorative props and pond props |
| `scripts/world_renderer.gd` | Rewrite: 16-variant grass fill layer → one `TileMapLayer` + `DualGridLayer` per overlay terrain (`SOIL` → grass_dirt, `WATER` → grass_water), `poll_seconds = 0`, one rebuild; `WaterGlints` on the water display layer; foot-anchored y-sorted props |
| `scripts/main.gd`, `scripts/camera_controller.gd` | `TILE_SIZE = 32` comes from the renderer, so `main.gd` needed no change; zoom default 2 / min 1 / max 4 (integer stops), speed 250 |
| `scenes/tree.tscn`, `scripts/tree.gd` | Rewire to kit textures (stage + species), keep `Area2D` |
| `scenes/grass.tscn` | Retire; tufts/decor become foot-anchored sprites spawned by the renderer |
| `tests/smoke_test.gd` | Replace shader/palette/mask assertions with tilemap ones: terrain mix, water banks, determinism, fill coverage, display-layer corner codes recomputed from terrain, glints, prop anchoring, rebuild |
| `README.md`, `design.md` | New world-gen section, tuning table, kit license + credit, fields as tilled plots |

## Order of work

1. **Import + 32 px switch** — copy kit, fix tileset paths, camera/zoom/speed, grass world renders.
2. **Terrain data + generation** — grass/soil/water with banks and determinism.
3. **Dual-grid rendering** — fill layer + two display layers + glints; seam and border check.
4. **Props** — trees (stage + species), tufts, decor, pond props; y-sort and anchoring.
5. **Fields** — soil plots, patch data, sparse tufts.
6. **Cleanup + docs.**
7. **QA** — several seeds, screenshots (wide, pond edge, path fork, field), build time, final headless run.

## Risks

- Only two blend sets: no soil↔water, cliffs or sand. The bank rule covers it; more
  biomes need the paid kit.
- No crop art and no growth-stage art: fields and tree stages are compromises.
- `WaterGlints` scans every display-layer pixel in GDScript (~2048² px). Measure the
  world-build time; fall back to per-tile glint scattering if it hitches.
- Dual-grid display tiles hang half a tile past the map border; force the outer ring
  to grass and check visually.
- License: usable in commercial games, not redistributable as an asset pack. Ship the
  kit's `LICENSE.txt` and credit VibeForge in the README.
