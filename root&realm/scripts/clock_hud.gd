class_name ClockHud
extends Control

## A wooden strip with the calendar line and the speed buttons. Time is
## read-only apart from speed — a simulation is not scrubbable, so there is no
## playhead or drag handle; the date itself is the readout.

const STRIP_SIZE := Vector2(196, 54)
const FONT_SIZE := 10
# "||" rather than a pause glyph: the fallback font has no icon coverage.
const SPEED_LABELS: Array[String] = ["||", "1x", "2x", "4x"]
const BUTTONS := 4
const BUTTON_HEIGHT := 14
const BUTTON_GAP := 4

const TEXT_COLOR := Color("f4e6c8")
# The strip's content sits in a recessed panel so the cream text always reads.
const PANEL_COLOR := Color("2a1e16")
const BUTTON_IDLE := Color("4b3527")
const BUTTON_ACTIVE := Color("926445")
const BUTTON_TEXT_IDLE := Color("d8c6a4")
const BUTTON_TEXT_ACTIVE := Color("fff6e0")

var clock: GameClock

var _drawn_tick := -1
var _drawn_speed := -1


func setup(new_clock: GameClock) -> void:
	clock = new_clock
	custom_minimum_size = STRIP_SIZE
	size = STRIP_SIZE
	queue_redraw()


func content_rect() -> Rect2:
	## The area inside the wooden frame. Everything below is laid out from it.
	return Rect2(
		Vector2.ONE * UiFrame.BORDER, size - Vector2.ONE * UiFrame.BORDER * 2.0
	)


func button_rects() -> Array[Rect2]:
	var content := content_rect()
	var width := (content.size.x - BUTTON_GAP * (BUTTONS - 1)) / float(BUTTONS)
	var y := content.position.y + FONT_SIZE + 6.0

	var rects: Array[Rect2] = []

	for index in range(BUTTONS):
		rects.append(
			Rect2(content.position.x + index * (width + BUTTON_GAP), y, width, BUTTON_HEIGHT)
		)

	return rects


func button_index_at(point: Vector2) -> int:
	## The speed button under a point, or -1. Kept argument-driven so the click
	## rule is testable without a pointer.
	for index in range(BUTTONS):
		if button_rects()[index].has_point(point):
			return index

	return -1


func _process(_delta: float) -> void:
	# One redraw per game tick: the calendar line only changes when the tick does.
	if clock == null or (clock.tick == _drawn_tick and clock.speed_index == _drawn_speed):
		return

	_drawn_tick = clock.tick
	_drawn_speed = clock.speed_index
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			return

		var index := button_index_at(event.position)

		if index >= 0:
			clock.set_speed_index(index)
			accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	## Space toggles pause; 1, 2, 4 pick a speed. Raw keys, because these are the
	## only time controls and an input action per button would be noise.
	var key := event as InputEventKey

	if key == null or not key.pressed or key.echo:
		return

	match key.keycode:
		KEY_SPACE:
			clock.toggle_pause()
		KEY_1:
			clock.set_speed_index(1)
		KEY_2:
			clock.set_speed_index(2)
		KEY_4:
			clock.set_speed_index(3)
		_:
			return

	queue_redraw()
	get_viewport().set_input_as_handled()


func _draw() -> void:
	UiFrame.draw(self, Rect2(Vector2.ZERO, size))
	draw_rect(content_rect(), PANEL_COLOR)

	if clock == null:
		return

	_draw_label()
	_draw_buttons()


func _draw_label() -> void:
	var content := content_rect()

	draw_string(
		ThemeDB.fallback_font,
		Vector2(content.position.x, content.position.y + FONT_SIZE),
		clock.label(),
		HORIZONTAL_ALIGNMENT_LEFT,
		content.size.x,
		FONT_SIZE,
		TEXT_COLOR
	)


func _draw_buttons() -> void:
	var font := ThemeDB.fallback_font

	for index in range(BUTTONS):
		var rect := button_rects()[index]
		var active := index == clock.speed_index

		draw_rect(rect, BUTTON_ACTIVE if active else BUTTON_IDLE)
		draw_string(
			font,
			Vector2(rect.position.x, rect.position.y + rect.size.y - 4.0),
			SPEED_LABELS[index],
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			FONT_SIZE,
			BUTTON_TEXT_ACTIVE if active else BUTTON_TEXT_IDLE
		)
