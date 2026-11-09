class_name DayNight
extends CanvasModulate
## Ciclo de día y noche. Tiñe el mundo y enciende las luces del grupo "night_lights".

signal new_day(day: int)

@export var day_length_sec: float = 240.0
@export var start_hour: float = 7.0

var hour: float = 7.0
var day: int = 1
var _gradient: Gradient
var _flame_time: float = 0.0


func _ready() -> void:
	add_to_group("day_night")
	hour = start_hour
	_gradient = Gradient.new()
	_gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.25, 0.33, 0.7, 0.77, 0.85, 1.0])
	_gradient.colors = PackedColorArray([
		Color(0.20, 0.26, 0.42), Color(0.25, 0.30, 0.46), Color(0.95, 0.70, 0.61), Color(1, 1, 1),
		Color(1, 0.97, 0.90), Color(1.0, 0.60, 0.40), Color(0.25, 0.29, 0.46), Color(0.20, 0.26, 0.42),
	])
	color = _gradient.sample(hour / 24.0)


func _process(delta: float) -> void:
	hour += delta * 24.0 / day_length_sec
	if hour >= 24.0:
		hour -= 24.0
		day += 1
		new_day.emit(day)
	color = _gradient.sample(hour / 24.0)
	var nf: float = night_factor()
	_flame_time += delta
	for l: Node in get_tree().get_nodes_in_group("night_lights"):
		var lamp: PointLight2D = l as PointLight2D
		var phase: float = lamp.global_position.x * 0.13 + lamp.global_position.y * 0.07
		var flicker: float = 1.0 + sin(_flame_time * 7.3 + phase) * 0.035 + sin(_flame_time * 12.7 + phase * 2.0) * 0.025
		lamp.energy = nf * 0.85 * flicker


## 0 = pleno día, 1 = noche cerrada.
func night_factor() -> float:
	if hour >= 7.0 and hour <= 18.0:
		return 0.0
	if hour > 18.0 and hour < 20.0:
		return smoothstep(18.0, 20.0, hour)
	if hour > 5.0 and hour < 7.0:
		return 1.0 - smoothstep(5.0, 7.0, hour)
	return 1.0


func is_night() -> bool:
	return night_factor() > 0.5


## Calor del sol: 1 al mediodía.
func heat() -> float:
	return clampf(1.0 - absf(hour - 13.5) / 3.5, 0.0, 1.0)


func time_string() -> String:
	return "%02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60.0)]


func phase_name() -> String:
	if hour >= 5.0 and hour < 7.5:
		return "Amanecer"
	if hour >= 7.5 and hour < 17.5:
		return "Día"
	if hour >= 17.5 and hour < 20.0:
		return "Atardecer"
	return "Noche"
