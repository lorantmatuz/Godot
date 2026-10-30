class_name GameClock
extends RefCounted

## The settlement's calendar: one integer tick is 15 game minutes, and every
## larger unit is derived from it. Storing time as a single counter means a save
## only needs the tick, and growth can be a function of age instead of a running
## timer.
##
## The calendar is the real one rather than an invented one: twelve months of
## their true lengths, a 365-day year, and seasons as the three-month slices
## people actually mean by the words. There are no leap years — a fixed year
## length keeps the tick maths exact and deterministic.

const MINUTES_PER_TICK := 15
const TICKS_PER_HOUR := 4
const HOURS_PER_DAY := 24
const TICKS_PER_DAY := TICKS_PER_HOUR * HOURS_PER_DAY

const MONTH_NAMES: Array[String] = [
	"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
]
const DAYS_PER_MONTH: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const MONTHS_PER_YEAR := 12
# The sum of DAYS_PER_MONTH, spelled out so the year length is a constant; a
# test keeps the two in step.
const DAYS_PER_YEAR := 365

const SEASONS_PER_YEAR := 4
const SEASON_NAMES: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
# The season each month belongs to, by MONTH_NAMES index: March opens spring,
# December opens winter, and the year's first day is mid-winter.
const MONTH_SEASON: Array[int] = [3, 3, 0, 0, 0, 1, 1, 1, 2, 2, 2, 3]

# A day is 20 real seconds at 1x: a season is about half an hour, a year about
# two hours, and 4x brings a year into a sitting. Ticks stay slow enough (208 ms
# each) that a per-tick simulation can still do work.
const REAL_SECONDS_PER_DAY := 20.0
const SECONDS_PER_TICK := REAL_SECONDS_PER_DAY / TICKS_PER_DAY
const SPEEDS: Array[float] = [0.0, 1.0, 2.0, 4.0]

# Total ticks since the world started. Everything else is derived from it.
var tick := 0
# Index into SPEEDS; 0 is paused.
var speed_index := 1

var _progress := 0.0
var _last_running_speed := 1


func advance(real_delta: float) -> int:
	## Advances by a real-time delta and returns the ticks that earned.
	## Fractional progress carries over, so many small deltas lose no time.
	var speed := SPEEDS[speed_index]

	if speed <= 0.0:
		return 0

	_progress += real_delta * speed / SECONDS_PER_TICK
	# The epsilon swallows the rounding of deltas that are exact multiples of a
	# tick; without it a HUD-time step can land a hair under the tick boundary.
	var ticks := int(floor(_progress + 1e-9))

	if ticks <= 0:
		return 0

	_progress -= ticks
	tick += ticks

	return ticks


func set_speed_index(index: int) -> void:
	speed_index = clampi(index, 0, SPEEDS.size() - 1)

	if speed_index != 0:
		_last_running_speed = speed_index


func toggle_pause() -> void:
	# Pausing remembers the running speed, so unpausing returns to it.
	speed_index = _last_running_speed if speed_index == 0 else 0


func is_paused() -> bool:
	return SPEEDS[speed_index] == 0.0


func speed_scale() -> float:
	## The multiplier world animation should run at, so nothing shimmers at its
	## own pace while the simulation is paused or running at 4x.
	return SPEEDS[speed_index]


func day() -> int:
	## Days since the world started, 0-based.
	return tick / TICKS_PER_DAY


func ticks_into_day() -> int:
	return tick % TICKS_PER_DAY


func minute_of_day() -> int:
	return ticks_into_day() * MINUTES_PER_TICK


func hour_of_day() -> int:
	return minute_of_day() / 60


func day_fraction() -> float:
	## Position within the current day: 0.0 at midnight, below 1.0.
	return float(ticks_into_day()) / TICKS_PER_DAY


func day_of_year() -> int:
	return day() % DAYS_PER_YEAR


func month() -> int:
	## Index into MONTH_NAMES, 0-based like every other unit here.
	var day_index := day_of_year()

	for index in range(MONTHS_PER_YEAR):
		day_index -= DAYS_PER_MONTH[index]

		if day_index < 0:
			return index

	return MONTHS_PER_YEAR - 1


func day_of_month() -> int:
	## The day as a calendar prints it, so 1-based.
	return day_of_year() - month_start(month()) + 1


func month_start(month_index: int) -> int:
	## Day of the year a month opens on, 0-based; the first of March is 59.
	var start := 0

	for index in range(clampi(month_index, 0, MONTHS_PER_YEAR - 1)):
		start += DAYS_PER_MONTH[index]

	return start


func season() -> int:
	return MONTH_SEASON[month()]


func season_name() -> String:
	return SEASON_NAMES[season()]


func year() -> int:
	return day() / DAYS_PER_YEAR


func month_name() -> String:
	return MONTH_NAMES[month()]


func date() -> String:
	## "Mar 4", the part of the label a player reads at a glance.
	return "%s %d" % [month_name(), day_of_month()]


func label() -> String:
	## The HUD line. Years and day numbers read 1-based to the player.
	return "%s · %s · Year %d" % [season_name(), date(), year() + 1]
