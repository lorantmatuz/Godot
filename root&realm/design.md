# Wildwood Frontier
## Game Design Document — Version 0.1

### 1. Game Overview

**Genre:** 2D top-down settlement strategy, resource management, light ecosystem simulation.

**Core concept:** Establish a settlement in a procedurally generated wilderness. Gather resources, construct production buildings, assign workers, and build an economy that can sustain itself while managing the natural environment.

**Design pillars:**
- Interconnected economic systems.
- Procedurally generated maps with meaningful resource distribution.
- Simple autonomous workers and a living forest.
- Strategy-first controls through a building menu and management interface.
- Small, achievable scope for a solo Godot developer.

**Core design principle:** Every expansion should solve one problem while creating another.

### 2. Core Gameplay Loop

1. Inspect the map and locate resources.
2. Construct buildings using stored resources.
3. Assign workers to production buildings.
4. Balance food consumption, production, and storage.
5. Expand into new territory to access additional resources.
6. Improve production efficiency and grow the settlement.
7. Manage the forest so renewable resources can recover.

The player acts as the planner of a living production system rather than directly controlling a character.

### 3. Initial Resources

Start with five primary resources:

- **Wood:** Construction material for houses, storage, farms, and workshops.
- **Stone:** Used for durable buildings and advanced construction.
- **Food:** Consumed by workers. Shortages stop population growth and reduce productivity.
- **Iron Ore:** A scarce resource found in deposits on the map.
- **Tools:** Produced using wood and iron ore. Improve the efficiency of selected production buildings.

Forests, stone deposits, fertile soil, and wildlife are world features rather than inventory resources.

### 4. Buildings and Production Chains

| Building | Function | Requirements |
|---|---|---|
| Camp | Starting base and initial storage | Starting structure |
| House | Increases population capacity | Wood, optionally stone |
| Woodcutter's Hut | Produces wood | Worker and nearby forest |
| Quarry | Produces stone | Worker and nearby stone deposit |
| Farm | Produces food | Worker and fertile land |
| Warehouse | Adds storage capacity | Wood |
| Workshop | Produces tools | Worker, wood, and iron ore |

Basic production chains:

- Forest → Woodcutter's Hut → Wood
- Stone Deposit → Quarry → Stone
- Fertile Soil → Farm → Food
- Wood + Stone → House → Housing Capacity
- Wood + Iron Ore → Workshop → Tools

Tools improve the output of woodcutters and quarry workers. This allows the player to increase production efficiency instead of solving every problem by recruiting more workers.

### 5. Population and Workers

For the initial version, workers have three main properties:

- Total population.
- Housing capacity.
- Assignment to a production building.

Workers consume food automatically over time. Buildings require assigned workers to operate.

Population can grow when the settlement has available housing, sufficient food, and the resources required to recruit a worker.

When food becomes scarce:
1. Production efficiency decreases.
2. Population growth stops.
3. Prolonged shortages may cause workers to leave or become unavailable.

Shortages should be recoverable rather than causing sudden game over.

Worker assignments are managed through the building interface. Animated workers can be added later without changing the underlying economy.

### 6. Procedural World Generation

**Initial map size:** 64 × 64 tiles.

Generation steps:
1. Generate coherent terrain using noise or patch-based algorithms.
2. Create forests, water bodies, rocky areas, and open ground.
3. Place stone deposits and fertile land.
4. Populate suitable terrain with trees.
5. Select a starting clearing with access to essential resources.
6. Place the player-independent starting settlement and initial stockpile.

Use a stored random seed so maps can be reproduced for debugging.

Every map should be winnable. Resource scarcity should create strategic choices, not make basic progression impossible.

Example map variations:
- Lumber Valley: abundant wood, distant stone.
- Rocky Meadow: abundant stone, limited forest.

### 7. Living Ecosystem

Trees are renewable resources with three growth stages:

1. Seedling.
2. Young tree.
3. Mature tree.

Simulation rules:
- Mature trees occasionally spread seeds to nearby suitable tiles.
- Seedlings grow after sufficient in-game time.
- Woodcutters harvest mature trees.
- Buildings occupy tiles and prevent tree growth there.

Harvesting faster than the forest recovers creates local resource shortages. The player must reduce harvesting, relocate production, or allow the forest to regenerate.

Wildlife is a potential future feature. Rabbits or deer could wander, seek food, and reproduce using simple rules, but animal populations are excluded from the first playable version.

### 8. Production and Simulation Architecture

Separate economic simulation from worker animation.

Buildings produce resources on discrete simulation ticks when:
- They have assigned workers.
- Their location meets production requirements.
- Required inputs are available.
- Output storage has sufficient capacity.

Suggested initial tick interval: 1–2 seconds of game time.

Suggested systems:

- **WorldGenerator:** Generates terrain, resources, and starting areas.
- **WorldGrid:** Stores terrain, buildings, and resource nodes.
- **ResourceManager:** Tracks inventories and construction costs.
- **Building:** Defines production, storage, worker slots, and recipes.
- **PopulationManager:** Tracks housing, workers, and food consumption.
- **SimulationManager:** Advances production, game time, and tree growth.
- **GameUI:** Displays resources, building options, and building status.

Use ordinary Godot scenes and GDScript classes. Avoid building a custom entity-component framework for this project.

### 9. User Interface

The strategy-first interface has four primary elements:

**Top resource bar**
- Wood.
- Stone.
- Food.
- Iron ore.
- Tools.
- Population and housing.

**Central world view**
- Top-down tile map.
- Selectable terrain, resource nodes, and buildings.
- Building placement and visual feedback.

**Build menu**
- Available buildings.
- Construction costs.
- Placement requirements.
- Unavailable buildings and their requirements.

**Building inspector**
- Worker assignments.
- Production rate.
- Input and output inventory.
- Operating status and reasons for shortages.

The interface must explain why production stops: insufficient workers, exhausted deposits, missing inputs, or full storage.

### 10. Progression and Objectives

**Stage 1 — Establish a camp**
- Build basic production buildings.
- Support three workers.

**Stage 2 — Become self-sufficient**
- Produce enough food to sustain the population.
- Expand housing and storage.

**Stage 3 — Improve production**
- Establish a workshop.
- Produce tools and increase resource output.

**Stage 4 — Expand sustainably**
- Develop another production area.
- Manage resource depletion.
- Support a larger population.

Initial victory condition: sustain ten workers, maintain a food reserve, and construct a functioning workshop.

After victory, the player can continue in sandbox mode.

### 11. Development Milestones

**Milestone 1 — A world you can build in**
- Generate and render a tile-based map.
- Add trees and stone deposits.
- Implement building placement and validation.

**Milestone 2 — A functioning economy**
- Implement wood, stone, and food.
- Add construction costs.
- Implement workers, production, and food consumption.
- Make farms and housing support a stable population.

**Milestone 3 — A living world**
- Add tree growth and seed spreading.
- Implement resource depletion and recovery.
- Add simple worker animations.

**Milestone 4 — A complete game loop**
- Add iron ore, the workshop, and tools.
- Implement settlement objectives.
- Add shortage warnings, saving/loading, and visual polish.

Rough estimate: 8–13 focused evenings, depending on familiarity with Godot and the amount of polish.

### 12. Explicitly Out of Scope for Version 0.1

- Combat and enemies.
- Hunting and animal populations.
- Complex transport networks and physical resource delivery.
- Individual worker inventories.
- Seasons and dynamic weather.
- Trading and diplomacy.
- Large technology trees.
- Hundreds of resources and buildings.
- Multiplayer.

These can be considered after the first version is enjoyable.

### 13. Definition of Success

The first version is successful if the player can:

1. Start a new, randomly generated world.
2. Build a small settlement using gathered resources.
3. Assign workers to production buildings.
4. Sustain workers through food production.
5. Encounter and resolve resource bottlenecks.
6. Improve production using tools.
7. Observe the forest recovering after harvesting.
8. Reach a clear settlement milestone and continue playing.

**Final design statement:** Wildwood Frontier is a small, procedurally generated settlement builder where the player balances workers, food, production chains, and a regenerating forest to grow a self-sustaining village.