extends SceneTree

# Headless smoke test: godot --headless --path breakout --script res://tests/smoke_test.gd

var failures := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	await _test_start_and_lives()
	await _test_paddle_bounds()
	await _test_win()
	await _test_ball_direction()
	await _test_paddle_motion()
	print("smoke test: ", "FAIL (%d)" % failures if failures > 0 else "PASS")
	quit(1 if failures > 0 else 0)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		failures += 1
	print(("  ok   " if ok else "  FAIL ") + label + ("  [" + detail + "]" if detail != "" else ""))

func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame

func _new_main():
	var main = load("res://scenes/levels/main.tscn").instantiate()
	root.add_child(main)
	await _wait(2)
	return main

func _drop_ball(main, paddle) -> void:
	var ball = main.get_node("%Ball")
	paddle.position.x = 75.0
	ball.attached = false
	ball.position = Vector2(540, 650)
	ball.velocity = Vector2(0, 420)

func _test_start_and_lives() -> void:
	print("start / lives")
	var main = await _new_main()
	var bodies := []
	main.get_node("%Walls/KillZone").body_entered.connect(func(b): bodies.append(b.name))
	await _wait(3)
	_check("starts with 3 lives", main.lives == 3, str(main.lives))
	_check("lives label matches", main.lives_label.text == "Lives: 3", main.lives_label.text)
	_check("walls do not trigger the kill zone", bodies.is_empty(), str(bodies))

	var paddle = main.get_node("Paddle")
	for expected in [2, 1]:
		_drop_ball(main, paddle)
		await _wait(80)
		_check("lives after a miss = %d" % expected, main.lives == expected, str(main.lives))
		_check("ball reattaches", main.get_node("%Ball").attached)

	_drop_ball(main, paddle)
	await _wait(80)
	_check("no lives left", main.lives == 0, str(main.lives))
	_check("state is LOST", main.state == main.State.LOST)
	_check("game-over label is visible", main.game_over_label.visible)
	_check("game-over text", main.game_over_label.text.contains("Game over"), main.game_over_label.text)
	_check("paddle stops", not paddle.is_physics_processing())

	main.queue_free()
	await process_frame

func _test_paddle_bounds() -> void:
	print("paddle bounds")
	var main = await _new_main()
	var paddle = main.get_node("Paddle")
	Input.action_press("move_right")
	await _wait(150)
	Input.action_release("move_right")
	_check("right edge stays on screen", is_equal_approx(paddle.position.x, 1005.0), str(paddle.position.x))
	Input.action_press("move_left")
	await _wait(150)
	Input.action_release("move_left")
	_check("left edge stays on screen", is_equal_approx(paddle.position.x, 75.0), str(paddle.position.x))

	main.queue_free()
	await process_frame

func _test_win() -> void:
	print("win")
	var main = await _new_main()
	for brick in main.get_node("%Bricks").get_children():
		if brick.is_in_group("brick"):
			brick.take_hit()
	await _wait(2)
	_check("state is WON", main.state == main.State.WON)
	_check("win label is visible", main.game_over_label.visible)
	_check("win text", main.game_over_label.text.contains("You win"), main.game_over_label.text)
	_check("ball stops", not main.ball.is_physics_processing())
	_check("paddle stops", not main.get_node("Paddle").is_physics_processing())

	var text: String = main.game_over_label.text
	main._on_ball_lost(main.ball)
	main._on_brick_died()
	_check("win is terminal", main.state == main.State.WON and main.game_over_label.text == text)
	_check("brick count does not go negative", main.bricks_left == 0, str(main.bricks_left))

	main.queue_free()
	await process_frame

func _wait_for_bounce(ball, initial_x: float) -> float:
	for i in 30:
		await physics_frame
		if not is_equal_approx(ball.velocity.x, initial_x):
			return ball.velocity.x
	return ball.velocity.x

func _test_paddle_motion() -> void:
	print("paddle motion")
	var main = await _new_main()
	var ball = main.get_node("%Ball")
	var paddle = main.get_node("Paddle")
	paddle.set_physics_process(false)
	paddle.position.x = 540.0

	# A motionless paddle's side must behave like a vertical wall.
	paddle.motion_velocity = 0.0
	ball.attached = false
	ball.position = Vector2(400, 700)
	ball.velocity = Vector2(420, 0)
	var vx := await _wait_for_bounce(ball, 420.0)
	_check("side hit at rest reflects", vx < -100.0, str(ball.velocity))

	# A paddle moving into the ball carries it along instead of reversing it.
	paddle.motion_velocity = 600.0
	ball.position = Vector2(400, 700)
	ball.velocity = Vector2(420, 0)
	vx = await _wait_for_bounce(ball, 420.0)
	_check("moving paddle pushes the side hit", vx > 100.0, str(ball.velocity))

	main.queue_free()
	await process_frame

func _test_ball_direction() -> void:
	print("ball direction")
	var main = await _new_main()
	var ball = main.get_node("%Ball")
	var paddle = main.get_node("Paddle")
	paddle.position.x = 540.0
	ball.attached = false
	ball.position = Vector2(540, 660)
	ball.velocity = Vector2(0, 420)
	await _wait(5)
	_check("dead-center hit keeps horizontal motion", absf(ball.velocity.x) >= 39.0, str(ball.velocity))
	_check("speed is preserved", is_equal_approx(ball.velocity.length(), 420.0), str(ball.velocity.length()))

	# Same hit, but with the paddle sliding sideways at full speed.
	var rest_vx := absf(ball.velocity.x)
	paddle.set_physics_process(false)
	paddle.motion_velocity = 600.0
	ball.position = Vector2(540, 660)
	ball.velocity = Vector2(0, 420)
	await _wait(5)
	_check("paddle motion biases the angle", absf(ball.velocity.x) > rest_vx + 50.0,
			"rest=%f moving=%s" % [rest_vx, str(ball.velocity)])
	_check("motion bias keeps the speed", is_equal_approx(ball.velocity.length(), 420.0), str(ball.velocity.length()))

	main.queue_free()
	await process_frame
