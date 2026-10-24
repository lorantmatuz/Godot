extends Node2D

const BRICK := preload("res://bricks.tscn")
const ROWS := 5
const COLS := 10
const BW := 100.0
const BH := 20.0
const GAP := 5.0

var score := 0
var lives := 3
var bricks_left := ROWS * COLS

@onready var ball: CharacterBody2D = %Ball
@onready var bricks: Node2D = %Bricks
@onready var walls: Node2D = %Walls
@onready var score_label: Label = %ScoreLabel
@onready var lives_label: Label = %LivesLabel
@onready var game_over_label: Label = %GameOverLabel

func _ready() -> void:
	walls.find_child("KillZone").body_entered.connect(_on_ball_lost)
	_spawn_bricks()

func _spawn_bricks() -> void:
	var vp := get_viewport_rect().size
	var start := Vector2((vp.x - (COLS - 1) * (BW + GAP) - BW) / 2.0, 140.0)
	print(start)
	for row in ROWS:
		for col in COLS:
			var brick := BRICK.instantiate()
			brick.position = start + Vector2(col * (BW + GAP), row * (BH + GAP))
			bricks.add_child(brick)
			brick.died.connect(_on_brick_died)

func _on_brick_died() -> void:
	score += 10
	bricks_left -= 1
	score_label.text = "Score: %d" % score
	if bricks_left == 0:
		game_over_label.text = "You win! Press R to restart"

func _on_ball_lost(_body: Node2D) -> void:
	lives -= 1
	lives_label.text = "Lives: %d" % lives
	if lives <= 0:
		game_over_label.text = "Game over. Press R to restart"
		ball.queue_free()
	else:
		ball.reset()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
