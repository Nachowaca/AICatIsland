extends Node2D
## Controlador principal: aparición de pescado, cámara y controles de observación.

@export var max_fish: int = 3
@export var spawn_interval: float = 22.0

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


func _process(delta: float) -> void:
	_spawn_t += delta
	# Al amanecer "los pescadores" dejan más pescado en la orilla
	var dawn: bool = day_night.hour > 5.0 and day_night.hour < 8.5
	if _spawn_t >= spawn_interval * (0.4 if dawn else 1.0):
		_spawn_t = 0.0
		if get_tree().get_nodes_in_group("fish").size() < max_fish:
			spawn_fish_at(island.shore_pairs[_rng.randi() % island.shore_pairs.size()])
	if _follow:
		var cat: Node2D = get_tree().get_first_node_in_group("cat") as Node2D
		if cat:
			camera.position = camera.position.lerp(cat.position, minf(1.0, 3.0 * delta))


func spawn_fish_at(pair: Array) -> void:
	var spots: Array = island.shore_spots(pair)
	var pos: Vector2 = spots[1]
	for n: Node in get_tree().get_nodes_in_group("fish"):
		if (n as Fish).grid_pos.distance_to(pos) < 0.6:
			return
	var f: Fish = Fish.new()
	f.name = "Fish"
	f.grid_pos = pos
	f.land_spot = spots[0]
	entities.add_child(f, true)


## Recoloca los pescados puestos a mano en la escena sobre la costa real.
func _snap_fish_to_shore() -> void:
	for n: Node in get_tree().get_nodes_in_group("fish"):
		var f: Fish = n as Fish
		var best: Array = []
		var bd: float = INF
		for pair: Array in island.shore_pairs:
			var dd: float = (pair[0] as Vector2).distance_to(f.grid_pos)
			if dd < bd:
				bd = dd
				best = pair
		if not best.is_empty():
			var spots: Array = island.shore_spots(best)
			f.grid_pos = spots[1]
			f.land_spot = spots[0]


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
