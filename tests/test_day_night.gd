class_name TestDayNight
extends Node

func test_transicion_solar_lunar_continua() -> void:
	var cycle: DayNight = DayNight.new()
	cycle.hour = 12.0
	assert(is_zero_approx(cycle.night_factor()))
	cycle.hour = 21.0
	assert(is_equal_approx(cycle.night_factor(), 1.0))
	assert(cycle.is_night())
	cycle.hour = 19.0
	assert(is_equal_approx(cycle.night_factor(), 0.5))
	cycle.hour = 6.0
	assert(is_equal_approx(cycle.night_factor(), 0.5))
	cycle.hour = 18.001
	assert(cycle.night_factor() < 0.00001)
	cycle.hour = 6.999
	assert(cycle.night_factor() < 0.00001)
	cycle.free()
