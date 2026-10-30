class_name TreeEntity
extends Node2D

## A tree in the world. The visual comes from the Cozy World Kit: the renderer
## picks the stage/species texture and calls apply_texture(), so a growth change
## only has to ask the renderer for a new one.

signal stage_changed(stage: TreeStage)

enum TreeStage {
	SEEDLING,
	YOUNG,
	MATURE,
	STUMP
}

# How solid a cutaway tree stays: enough to read the canopy, thin enough to see
# what stands behind it.
const CUTAWAY_ALPHA := 0.45

@export var growth_stage: TreeStage = TreeStage.MATURE
@export var species := ""

var faded := false

@onready var sprite: Sprite2D = $Sprite2D


func set_faded(new_faded: bool) -> void:
	## A tree whose canopy hides the pointer goes see-through, so a building
	## behind it can be seen: a top-down view has no camera rotation to look
	## around a canopy.
	if new_faded == faded:
		return

	faded = new_faded
	sprite.modulate.a = CUTAWAY_ALPHA if faded else 1.0


func set_growth_stage(new_stage: TreeStage) -> void:
	growth_stage = new_stage
	stage_changed.emit(growth_stage)


func apply_texture(texture: Texture2D) -> void:
	if texture == null:
		push_warning("Tree texture is not assigned.")
		return

	# Kit props sit on transparent canvases whose foot is the bottom centre, so
	# keep the node origin at the foot and draw the sprite upwards from there.
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = Vector2(-texture.get_width() / 2.0, -texture.get_height())
