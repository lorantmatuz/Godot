extends Node2D

const BRICK := preload("res://scenes/bricks.tscn")
const ROWS := 5
const COLS := 10
const BW := 100.0
const BH := 20.0
const GAP := 5.0

enum State { PLAYING, WON, LOST }

var score := 0
var lives := 3
var bricks_left := ROWS * COLS
var state := State.PLAYING

@onready var ball: CharacterBody2D = %Ball
@onready var paddle: CharacterBody2D = $Paddle
@onready var bricks: Node2D = %Bricks
@onready var kill_zone: Area2D = $Walls/KillZone
@onready var score_label: Label = %ScoreLabel
@onready var lives_label: Label = %LivesLabel
@onready var game_over_label: Label = %GameOverLabel

func _ready() -> void:
	kill_zone.body_entered.connect(_on_ball_lost)
	_spawn_bricks()

func _spawn_bricks() -> void:
	var vp := get_viewport_rect().size
	var start := Vector2((vp.x - (COLS - 1) * (BW + GAP) - BW) / 2.0, 140.0)
	for row in ROWS:
		for col in COLS:
			var brick := BRICK.instantiate()
			brick.position = start + Vector2(col * (BW + GAP), row * (BH + GAP))
			bricks.add_child(brick)
			brick.died.connect(_on_brick_died)

func _on_brick_died() -> void:
	if state != State.PLAYING:
		return
	score += 10
	bricks_left -= 1
	score_label.text = "Score: %d" % score
	if bricks_left == 0:
		state = State.WON
		_end_game("You win! Press R to restart")

func _on_ball_lost(body: Node2D) -> void:
	# The kill zone also catches the side walls; only the ball ends a life.
	if state != State.PLAYING or body != ball:
		return
	lives -= 1
	lives_label.text = "Lives: %d" % lives
	if lives <= 0:
		state = State.LOST
		_end_game("Game over. Press R to restart")
		ball.queue_free()
	else:
		ball.reset()

func _end_game(message: String) -> void:
	game_over_label.text = message
	game_over_label.visible = true
	ball.set_physics_process(false)
	paddle.set_physics_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
