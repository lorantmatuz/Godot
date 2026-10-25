extends Node2D

@onready var left_wall: StaticBody2D = $LeftWall
@onready var right_wall: StaticBody2D = $RightWall
@onready var top_wall: StaticBody2D = $TopWall
@onready var kill_zone: Area2D = $KillZone

const WALL_THICKNESS := 1.0
const KILL_ZONE_HEIGHT := 100.0

func _ready() -> void:
	update_walls()

func update_walls() -> void:
	var viewport_size := get_viewport_rect().size
	var w := viewport_size.x
	var h := viewport_size.y
	var t := WALL_THICKNESS
	var wall_height := h - t  # stop above the kill zone so walls don't trigger it

	# Left wall
	left_wall.position = Vector2(t / 2.0, wall_height / 2.0)
	left_wall.get_node("CollisionShape2D").shape.size = Vector2(t, wall_height)

	# Right wall
	right_wall.position = Vector2(w - t / 2.0, wall_height / 2.0)
	right_wall.get_node("CollisionShape2D").shape.size = Vector2(t, wall_height)

	# Top wall
	top_wall.position = Vector2(w / 2.0, t / 2.0)
	top_wall.get_node("CollisionShape2D").shape.size = Vector2(w + 2.0 * t, t)

	# Bottom kill zone
	kill_zone.position = Vector2(w / 2.0, h + KILL_ZONE_HEIGHT / 2.0)
	kill_zone.get_node("CollisionShape2D").shape.size = Vector2(w, KILL_ZONE_HEIGHT)
