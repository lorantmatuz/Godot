class_name BuildingDefs
extends RefCounted

## The building roster as data: one entry per building, so `Placement.can_place()`
## answers from the table instead of a pile of special cases.
##
## `size` is the footprint in tiles, anchored at its top-left. `requirement` is
## the site rule checked in a radius around the footprint: a woodcutter wants
## mature trees, a farm wants tilled soil, a house wants nothing but room.
##
## Costs and worker slots are deliberately absent — nothing pays for a building
## or staffs it until the inventory and worker systems exist, and a field nothing
## reads would only drift. Every texture is a Cozy World Kit prop standing in
## until real building art arrives.

const TENT := preload("res://assets/cozy_world_kit/props/props_32/tent.png")
const MARKET_STALL := preload(
	"res://assets/cozy_world_kit/props/props_64/fruit_market_stall.png"
)
const LOG_PILE := preload(
	"res://assets/cozy_world_kit/props/props_64/chopped_log_pile.png"
)
const FARM_CART := preload("res://assets/cozy_world_kit/props/props_64/farm_cart.png")

# The camp is 1x1 because its stand-in is a 32 px tent; a 2x2 plot would look
# like one tent lost in a field.
const DEFINITIONS := {
	"camp": {
		"name": "Camp",
		"size": Vector2i.ONE,
		"terrain": [WorldGrid.Terrain.GRASS, WorldGrid.Terrain.SOIL],
		"requirement": {},
		"texture": TENT,
	},
	"house": {
		"name": "House",
		"size": Vector2i(2, 2),
		"terrain": [WorldGrid.Terrain.GRASS, WorldGrid.Terrain.SOIL],
		"requirement": {},
		"texture": MARKET_STALL,
	},
	"woodcutter": {
		"name": "Woodcutter's Hut",
		"size": Vector2i.ONE,
		"terrain": [WorldGrid.Terrain.GRASS],
		"requirement": {"kind": "trees", "radius": 6.0, "count": 5},
		"texture": LOG_PILE,
	},
	"farm": {
		"name": "Farm",
		"size": Vector2i(2, 2),
		"terrain": [WorldGrid.Terrain.GRASS],
		"requirement": {"kind": "soil", "radius": 4.0, "count": 8},
		"texture": FARM_CART,
	},
}

# The order the roster is walked in until there is a build menu.
const ORDER: Array[String] = ["camp", "house", "woodcutter", "farm"]


static func ids() -> Array[String]:
	return ORDER


static func get_def(id: String) -> Dictionary:
	return DEFINITIONS.get(id, {})
