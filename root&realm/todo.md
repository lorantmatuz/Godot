# Root & Realm — plan

Checkboxes are the remaining work; the diary at the bottom records what is
already in and why it was done that way. `design.md` stays the spec; this file
is only the order of attack.

Two rules that shaped the ordering below:

- **The player plans, workers act.** Cutting a tree is a worker's job on a
  simulation tick, not a click. There is no click-to-delete.
- **Time comes first.** Growth, production, food, and seasons are all functions
  of the clock, so it is built before anything that depends on it.

## Milestone 0 — time

- [x] 1. Game clock
	One integer tick (15 game minutes) drives everything; day, season, and year
	are derived from it, so growth can be a function of age and save/load only
	needs the tick.
	- [x] calendar: 96 ticks/day, the real 365-day year of twelve true-length
	      months, seasons as three-month slices (modelled, no effects yet)
	- [x] pause / 1× / 2× / 4×, remembered across pause
	- [x] HUD strip: calendar line and speed buttons; read-only apart from speed
	- [x] world animation (water glints) retimed to the game speed
	- [ ] seasonal effects (crop growth, colour shifts) — calendar only for now

## Milestone 1 — a world you can build in

- [x] 2. World grid and terrain
	64×64 grass base with soil and water overlays, dual-grid corner blending,
	one-tile water bank, deterministic from `WORLD_SEED`.
- [x] 3. Tree, rock, and prop objects
	4 tree species × 4 stages, ids, `objects_by_id` / `objects_by_tile`, rect
	`pick()`, `remove_object()` as an internal API for the simulation.
- [x] 4. Building placement
	- [x] building definitions as data (one entry per building): id, footprint,
	      allowed terrain, site requirements, texture — camp, house, woodcutter
	      and farm; cost and worker slots wait for inventory and workers
	- [x] ground rules per footprint tile: grass / soil / water, per building
	      (a dock's "water with land adjacent" waits for a water building)
	- [x] clearance: no object on any footprint tile, and every footprint tile is
	      indexed, not just the anchor
	- [x] site requirements in a radius: mature trees for the woodcutter, tilled
	      soil for the farm (rock deposits wait on real stone)
	- [x] `can_place(world, building_id, tile) -> Reason`, a reason rather than a
	      bool, so the ghost can say *why* it is red
	- [x] placement mode with ghost preview; left click commits, right/Esc
	      cancels; middle-drag pan landed here because the left button is taken
	- [ ] artist stand-ins for the rest of the roster: `covered_stone_well`
	      (well), `big_mossy_boulder_formation` (quarry) — the four shipped
	      buildings use `tent`, `fruit_market_stall`, `chopped_log_pile` and
	      `farm_cart`
- [ ] 5. Tree growth
	- [ ] age-based: a tree stores `planted_tick`, stage is `stage_at(age)`
	- [ ] one pass per tick compares derived stage with the stored one and only
	      then calls `set_growth_stage()` (the renderer already swaps the texture)
	- [ ] thresholds in game days, so seedling → young → mature reads as weeks
- [ ] 6. Buildability flag
	Soil currently means *camp clearing*, *dirt trail*, and *tilled field* at
	once, so "build on soil" would put a house on a footpath. Add a per-tile
	`buildable` byte (and let fields/trails clear it) instead of overloading
	terrain.

## Milestone 2 — a functioning economy

- [ ] 7. Resource inventory
	- [ ] `Inventory` RefCounted: wood, stone, food, iron ore, tools
	- [ ] HUD bar: resources + population/housing
	- [ ] camp gets starting storage
- [ ] 8. Workers and harvesting
	- [ ] worker entity that walks to a designated work area — **the only way a
	      tree is felled**; mature tree → `STUMP` on arrival
	- [ ] forestry zone / hut radius as the player's only lever on harvesting
	- [ ] woodcutter's hut: construction cost, one worker slot, nearby trees →
	      wood
	- [ ] production on clock ticks (the design's "1–2 seconds of game time"
	      predates the decades-long calendar; expect per-game-hour instead)
- [ ] 9. Food and population
	Prices, housing capacity, assignments, food consumption, growth, and
	recoverable shortages (never an instant loss).

## Milestone 3 — a living world

- [ ] 10. Forest regeneration
	Mature trees spread seeds onto suitable grass; seedlings climb the stage
	ladder from 5; buildings block growth.
- [ ] 11. Polish and objectives
	- [ ] inspection on click (species, stage, age, "in reach of hut X") — needs
	      something worth inspecting, hence late
	- [ ] shortage warnings ("no worker", "no trees in reach", "storage full")
	- [ ] save / load (a saved `tick` plus object dicts is most of it)
	- [ ] victory check from `design.md` §10, then sandbox
	- [ ] real building art

## Loose ends

- `scenes/tree.tscn` carries an unused `Area2D` + `CollisionShape2D`, which
  contradicts the README's "picking is a sprite-rect hit test" decision.
- Mouse-wheel zoom is still missing; drag-pan landed with placement.
- Stone is purely decorative (`small_rocks_cluster`, `mossy_rock`); design §4
  wants real deposits for the quarry to key off.
- `scripts/world_generator.gd` is ~600 lines and will grow again when deposits
  arrive; consider splitting resource placement out.
- `TreeEntity.apply_texture()` and `WorldRenderer._apply_texture()` duplicate the
  foot-anchoring maths.

## Rules that keep the tests cheap

New logic goes in a pure, argument-driven function (`can_place`, `stage_at`,
`mouse_edge_direction` did) rather than into `_process` or an `Input` handler, so
`tests/` can call it headlessly. Every test file exits non-zero on failure; CI
runs every `tests/test_*.gd` per game.

## Diary

### 2026-10-27 — skeleton
First commit: camera, `world_generator.gd` / `world_renderer.gd`, a tree scene,
smoke tests, rocks and grass props. This plan was written the same day.

### 2026-10-28 — shader detour
Terrain was drawn by a shader for a day, then tuned and abandoned.

### 2026-10-29 — Cozy World Kit, ids, camera, minimap
Switched the art to the Cozy World Kit (32 px tiles) and dropped the shader for
`TileMapLayer` + dual-grid corner blends — this is why soil and water can only
be painted *over* grass, and why water keeps a grass bank. Objects got stable
ids plus `objects_by_tile`, so removal drops data and visual together. Camera
gained edge scrolling; the minimap was added as a `Control` rendered straight
from `WorldGrid`. Tests were split one file per theme. Fixed a 32 vs 16 px bug
that left a grass strip along blend edges.

### 2026-10-30 — minimap polish, tooling, status check
Minimap colours and detail, GDScript formatter addon, README example scene, and
lint fixes. Full suite re-run locally against Godot 4.7.2: all six files pass.

### 2026-10-30 — plan revised after review
Three corrections from playing with the world:

1. No click-to-harvest. The player designates *where* work happens; a worker
   fells the tree. Selection survives only as inspection, and moves late.
2. Time is long: seasons later, years and decades overall. That forces the clock
   to be the first system, and means growth is stored as an age, not a timer.
3. Building placement is per-building data, because some buildings want grass,
   some tilled soil, some open water with a shore. Hence the definition table
   and `can_place()` returning a reason.

Clock landed the same day: `scripts/game_clock.gd` plus `ClockHud` (option A
strip), sharing the minimap's wooden frame via `UiFrame`.

### 2026-10-30 — clock review
Three corrections after playing with the clock:

1. The day bar went. A read-only bar that only repeated the date was noise, so
   the strip is two rows: calendar line, speed buttons.
2. The calendar became the real one. 28-day seasons and 112-day years were
   invented numbers; twelve true-length months and seasons of the three months
   people mean by them read as a calendar. 365 days, no leap years, so the maths
   stays exact.
3. The water glints were retimed to the game speed. The kit's addon animates on
   real seconds, so `WorldRenderer.set_time_scale()` divides the frame interval
   instead of patching the addon; a paused world is glass.

### 2026-10-30 — placement and the pale ghost
Placement landed, narrow on purpose: four buildings (camp, house, woodcutter,
farm) rather than the whole roster, because rules for a quarry would be guesses
until stone exists. `can_place()` returns a reason rather than a bool, every
footprint tile is checked and indexed, and site rules count mature trees or
tilled soil in a radius — that radius is the only place the map touches the
economy, so it got the attention.

The preview is what makes the system usable: the stand-in at partial alpha, the
footprint tinted green or red, and the reason printed under the frame when red.
Arming is a key (`B` walks the roster) until the build menu exists, middle-drag
pan moved here because the left button is taken, and nothing costs anything yet.
