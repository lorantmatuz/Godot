extends CharacterBody2D

@onready var half_width: float = ($CollisionShape2D.shape as RectangleShape2D).size.x / 2.0

func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	position.x = clampf(position.x + dir * 600.0 * delta, 60.0, get_viewport_rect().size.x - 60.0)
	# mouse version instead: position.x = get_global_mouse_position().x
