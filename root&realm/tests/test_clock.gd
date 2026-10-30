extends "res://tests/_test_case.gd"

# Time: the calendar maths, the fractional accumulation, the speed controls, and
# the clock strip's layout and clicks.


func run() -> void:
	print("clock")
	_test_calendar()
	_test_accumulation()
	await _test_strip()


func _test_calendar() -> void:
	var clock := GameClock.new()

	check(
		"a fresh clock starts on 1 January of year 1, in winter",
		clock.tick == 0
		and clock.day() == 0
		and clock.month() == 0
		and clock.day_of_month() == 1
		and clock.season() == 3
		and clock.season_name() == "Winter"
		and clock.year() == 0
		and clock.label() == "Winter · Jan 1 · Year 1",
		clock.label()
	)

	var month_days := 0

	for count in GameClock.DAYS_PER_MONTH:
		month_days += count

	check(
		"the months add up to a 365-day year",
		month_days == GameClock.DAYS_PER_YEAR and GameClock.DAYS_PER_YEAR == 365,
		"%d days" % month_days
	)

	clock.tick = GameClock.TICKS_PER_DAY / 4
	check(
		"a quarter day is 06:00 and a quarter of the day",
		clock.hour_of_day() == 6
		and clock.minute_of_day() == 6 * 60
		and is_equal_approx(clock.day_fraction(), 0.25),
		"%d min, %.2f" % [clock.minute_of_day(), clock.day_fraction()]
	)

	clock.tick = GameClock.TICKS_PER_DAY * 31
	check(
		"31 days roll the calendar into February",
		clock.month_name() == "Feb" and clock.day_of_month() == 1 and clock.season_name() == "Winter",
		clock.label()
	)

	var reference := GameClock.new()
	var spring_first := reference.month_start(2)
	var winter_first := reference.month_start(11)

	clock.tick = GameClock.TICKS_PER_DAY * (GameClock.DAYS_PER_YEAR + spring_first)
	check(
		"1 March opens spring in year 2",
		clock.season_name() == "Spring"
		and clock.date() == "Mar 1"
		and clock.year() == 1
		and clock.label() == "Spring · Mar 1 · Year 2",
		clock.label()
	)

	clock.tick = GameClock.TICKS_PER_DAY * (GameClock.DAYS_PER_YEAR + spring_first - 1)
	check(
		"the last day of February is still winter",
		clock.date() == "Feb 28" and clock.season_name() == "Winter",
		clock.label()
	)

	clock.tick = GameClock.TICKS_PER_DAY * winter_first
	check(
		"1 December opens winter",
		clock.date() == "Dec 1" and clock.season_name() == "Winter",
		clock.label()
	)

	clock.tick = GameClock.TICKS_PER_DAY * (GameClock.DAYS_PER_YEAR - 1)
	check(
		"the year ends on 31 December",
		clock.date() == "Dec 31" and clock.year() == 0,
		clock.label()
	)

	clock.tick = GameClock.TICKS_PER_DAY * GameClock.DAYS_PER_YEAR
	check(
		"day 365 starts the next year on 1 January",
		clock.date() == "Jan 1" and clock.year() == 1 and clock.day() == GameClock.DAYS_PER_YEAR,
		clock.label()
	)

	var days := GameClock.DAYS_PER_YEAR * 2 + 5
	clock.tick = GameClock.TICKS_PER_DAY * days
	check(
		"days roll into years",
		clock.year() == 2 and clock.date() == "Jan 6" and clock.label() == "Winter · Jan 6 · Year 3",
		clock.label()
	)

	clock.tick = GameClock.TICKS_PER_DAY * GameClock.DAYS_PER_YEAR * 12
	check(
		"the calendar keeps counting decades",
		clock.year() == 12
		and clock.season() == 3
		and clock.day() == 12 * GameClock.DAYS_PER_YEAR,
		clock.label()
	)


func _test_accumulation() -> void:
	var clock := GameClock.new()
	var ticks := clock.advance(GameClock.REAL_SECONDS_PER_DAY)

	check(
		"twenty real seconds at 1x are one game day",
		ticks == GameClock.TICKS_PER_DAY and clock.tick == GameClock.TICKS_PER_DAY,
		"%d ticks" % ticks
	)

	clock = GameClock.new()

	# Small frames must not lose time: 240 frames of 0.1 s is 24 s, 115.2 ticks.
	for frame in range(240):
		clock.advance(0.1)

	check(
		"many small deltas accumulate without drift",
		clock.tick == 115,
		"%d ticks" % clock.tick
	)

	clock = GameClock.new()
	clock.set_speed_index(2)
	clock.advance(GameClock.SECONDS_PER_TICK * 4.0)
	var fast := clock.tick
	clock = GameClock.new()
	clock.advance(GameClock.SECONDS_PER_TICK * 4.0)

	check("2x earns twice the ticks of 1x", fast == clock.tick * 2, "%d vs %d" % [fast, clock.tick])

	clock = GameClock.new()
	clock.set_speed_index(1)
	clock.toggle_pause()

	var paused := clock.advance(GameClock.REAL_SECONDS_PER_DAY)

	check(
		"a paused clock earns nothing",
		paused == 0 and clock.tick == 0 and clock.is_paused() and clock.speed_scale() == 0.0
	)

	clock.toggle_pause()
	check(
		"unpausing returns to the speed it was paused at",
		clock.speed_index == 1 and not clock.is_paused() and clock.speed_scale() == 1.0
	)

	clock.set_speed_index(3)
	check(
		"the speed scale follows the buttons",
		is_equal_approx(clock.speed_scale(), GameClock.SPEEDS[3]),
		"%.1f" % clock.speed_scale()
	)

	clock.set_speed_index(99)
	var clamped_high := clock.speed_index
	clock.set_speed_index(-5)
	check(
		"speed indices clamp to the button range",
		clamped_high == GameClock.SPEEDS.size() - 1 and clock.speed_index == 0,
		"%d and %d" % [clamped_high, clock.speed_index]
	)


func _test_strip() -> void:
	var scene: PackedScene = load("res://scenes/levels/main.tscn")
	var main = scene.instantiate()
	(main.get_node("Camera2D") as CameraController).edge_margin = 0.0
	root.add_child(main)
	await process_frame

	var clock: GameClock = main.clock
	var strip: ClockHud = main.clock_hud
	var content := strip.content_rect()

	check(
		"the strip is a HUD control on a screen-space layer",
		strip.get_parent() is CanvasLayer
		and strip.size == ClockHud.STRIP_SIZE
		and content.size == ClockHud.STRIP_SIZE - Vector2.ONE * UiFrame.BORDER * 2.0,
		"%s px, content %s" % [strip.size, content.size]
	)
	check(
		"the calendar line and the speed buttons fit inside the frame",
		strip.button_rects()[0].position.y > content.position.y + ClockHud.FONT_SIZE
		and strip.button_rects()[-1].end.y <= content.end.y,
		"buttons %s..%.1f, content ends %.1f"
		% [strip.button_rects()[0].position.y, strip.button_rects()[-1].end.y, content.end.y]
	)

	clock.tick = 0
	var hit := 0

	for index in range(ClockHud.BUTTONS):
		if strip.button_index_at(strip.button_rects()[index].get_center()) == index:
			hit += 1

	check(
		"every speed button is clickable, and only those",
		hit == ClockHud.BUTTONS
		and strip.button_index_at(Vector2.ZERO) == -1
		and strip.button_index_at(content.position + Vector2(4.0, 4.0)) == -1,
		"%d of %d" % [hit, ClockHud.BUTTONS]
	)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = strip.button_rects()[3].get_center()
	strip._gui_input(click)
	check("clicking 4x sets the clock to 4x", clock.speed_index == 3, "index %d" % clock.speed_index)

	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	strip._unhandled_key_input(key)
	var paused_after_space := clock.is_paused()
	key = InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_2
	strip._unhandled_key_input(key)

	check(
		"space pauses and 2 resumes at 2x",
		paused_after_space and clock.speed_index == 2,
		"paused %s, index %d" % [paused_after_space, clock.speed_index]
	)

	var before := clock.tick
	clock.set_speed_index(1)
	main._process(GameClock.REAL_SECONDS_PER_DAY)
	check(
		"the main scene advances the clock from _process",
		absi(clock.tick - before - GameClock.TICKS_PER_DAY) <= 1,
		"%d -> %d" % [before, clock.tick]
	)
	check(
		"the water shimmer is retimed to the game speed",
		is_equal_approx(main.world_renderer.time_scale, 1.0)
		and main.world_renderer.glints.frame_ms == roundi(WorldRenderer.GLINT_FRAME_MS),
		"%d ms at %.0fx" % [main.world_renderer.glints.frame_ms, main.world_renderer.time_scale]
	)

	clock.set_speed_index(3)
	main._process(0.0)
	check(
		"4x shimmers four times faster",
		main.world_renderer.time_scale == 4.0
		and main.world_renderer.glints.frame_ms == roundi(WorldRenderer.GLINT_FRAME_MS / 4.0),
		"%d ms at %.0fx" % [main.world_renderer.glints.frame_ms, main.world_renderer.time_scale]
	)

	clock.toggle_pause()
	main._process(0.0)
	check(
		"a paused simulation freezes the shimmer",
		not main.world_renderer.glints.playing and main.world_renderer.time_scale == 0.0,
		"playing %s" % main.world_renderer.glints.playing
	)

	main.queue_free()
	finish()
