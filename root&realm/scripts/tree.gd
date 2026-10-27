extends Node2D
class_name TreeEntity

enum TreeStage {
	SEEDLING,
	YOUNG,
	MATURE,
	STUMP
}

@export var growth_stage: TreeStage = TreeStage.MATURE

@onready var sprite: Sprite2D = $Sprite2D

@export var seedling_texture: Texture2D
@export var young_texture: Texture2D
@export var mature_texture: Texture2D
@export var stump_texture: Texture2D

@export var seedling_offset: Vector2
@export var young_offset: Vector2
@export var mature_offset: Vector2
@export var stump_offset: Vector2


func _ready() -> void:
	update_visual()


func update_visual() -> void:
	var selected_texture: Texture2D
	var selected_offset: Vector2

	match growth_stage:
		TreeStage.SEEDLING:
			selected_texture = seedling_texture
			selected_offset = seedling_offset

		TreeStage.YOUNG:
			selected_texture = young_texture
			selected_offset = young_offset

		TreeStage.MATURE:
			selected_texture = mature_texture
			selected_offset = mature_offset

		TreeStage.STUMP:
			selected_texture = stump_texture
			selected_offset = stump_offset

	if selected_texture == null:
		push_warning("Tree texture is not assigned.")
		return

	sprite.texture = selected_texture
	sprite.offset = selected_offset


func set_growth_stage(new_stage: TreeStage) -> void:
	growth_stage = new_stage

	# Callers may set the stage before the node enters the tree; _ready applies it.
	if is_node_ready():
		update_visual()
