class_name IslandGame
extends Node2D
## Controlador principal: aparición de pescado, cámara y controles de observación.

@export var max_fish: int = 12
@export var initial_fish: int = 8
@export var spawn_interval: float = 8.0

const FISH_SEPARATION: float = 1.3

@onready var island: Island = $Island
@onready var entities: Node2D = $Entities
@onready var day_night: DayNight = $DayNight
@onready var camera: Camera2D = $Camera2D

var _spawn_t: float = 0.0
var _follow: bool = true
var _dragging: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_snap_fish_to_shore()
	_supply_fish(clampi(initial_fish, 0, maxi(0, max_fish)))


func _process(delta: float) -> void:
	_spawn_t += delta
	# Al amanecer "los pescadores" dejan más pescado en la orilla
	var dawn: bool = day_night.hour > 5.0 and day_night.hour < 8.5
	if _spawn_t >= spawn_interval * (0.4 if dawn else 1.0):
		_spawn_t = 0.0
		_supply_fish(mini(_live_fish().size() + 1, maxi(0, max_fish)))
	if _follow:
		var cat: Node2D = get_tree().get_first_node_in_group("cat") as Node2D
		if cat:
			camera.position = camera.position.lerp(cat.position, minf(1.0, 3.0 * delta))


## Los peces consumidos no ocupan cupo ni bloquean su antigua posición.
func _live_fish() -> Array[Fish]:
	var out: Array[Fish] = []
	for n: Node in get_tree().get_nodes_in_group("fish"):
		if n is Fish and not n.is_queued_for_deletion():
			out.append(n as Fish)
	return out


func _valid_shore_spots(pair: Array) -> Array:
	if not island.shore_pairs.has(pair):
		return []
	var spots: Array = island.shore_spots(pair)
	if not island.is_walkable(spots[0]):
		return []
	return spots


func _fish_space_free(pos: Vector2, fish: Array[Fish]) -> bool:
	for f: Fish in fish:
		if f.grid_pos.distance_to(pos) < FISH_SEPARATION:
			return false
	return true


## Tanto el suministro automático como los clics pasan por el mismo contrato.
func spawn_fish_at(pair: Array) -> bool:
	var fish: Array[Fish] = _live_fish()
	if fish.size() >= maxi(0, max_fish):
		return false
	var spots: Array = _valid_shore_spots(pair)
	if spots.is_empty() or not _fish_space_free(spots[1], fish):
		return false
	var f: Fish = Fish.new()
	f.name = "Fish"
	f.grid_pos = spots[1]
	f.land_spot = spots[0]
	entities.add_child(f, true)
	return true


## Una pasada aleatoria sin reemplazo: intentos acotados incluso con costa llena.
func _supply_fish(target: int) -> void:
	if _live_fish().size() >= target:
		return
	var pairs: Array = island.shore_pairs.duplicate()
	for i: int in range(pairs.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Array = pairs[i]
		pairs[i] = pairs[j]
		pairs[j] = tmp
	for pair: Array in pairs:
		if _live_fish().size() >= mini(target, maxi(0, max_fish)):
			break
		spawn_fish_at(pair)


## Conserva los peces de escena cuando caben, sin apilarlos al ajustar la costa.
func _snap_fish_to_shore() -> void:
	var placed: Array[Fish] = []
	for f: Fish in _live_fish():
		var best: Array = []
		var bd: float = INF
		if placed.size() < maxi(0, max_fish):
			for pair: Array in island.shore_pairs:
				var spots: Array = _valid_shore_spots(pair)
				if spots.is_empty() or not _fish_space_free(spots[1], placed):
					continue
				var dd: float = (spots[1] as Vector2).distance_to(f.grid_pos)
				if dd < bd:
					bd = dd
					best = spots
		if best.is_empty():
			f.queue_free()
		else:
			f.grid_pos = best[1]
			f.land_spot = best[0]
			placed.append(f)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
		if not mb.pressed:
			return
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_drop_fish_near(Iso.to_grid(get_global_mouse_position()))
			MOUSE_BUTTON_WHEEL_UP:
				camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.5, 0.5), Vector2(4, 4))
			MOUSE_BUTTON_WHEEL_DOWN:
				camera.zoom = (camera.zoom / 1.1).clamp(Vector2(0.5, 0.5), Vector2(4, 4))
	elif event is InputEventMouseMotion and _dragging:
		_follow = false
		camera.position -= (event as InputEventMouseMotion).relative / camera.zoom
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_1:
				Engine.time_scale = 1.0
			KEY_2:
				Engine.time_scale = 4.0
			KEY_3:
				Engine.time_scale = 10.0
			KEY_C:
				_follow = not _follow
			KEY_F, KEY_F11:
				var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_R:
				var cat: Cat = get_tree().get_first_node_in_group("cat") as Cat
				if cat:
					cat.reset_brain()


func _drop_fish_near(g: Vector2) -> void:
	var best: Array = []
	var bd: float = 2.5
	for pair: Array in island.shore_pairs:
		var d: float = (pair[0] as Vector2).distance_to(g)
		if d < bd:
			bd = d
			best = pair
	if not best.is_empty():
		spawn_fish_at(best)
