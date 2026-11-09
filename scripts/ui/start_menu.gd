class_name StartMenu
extends Node
## Isla de presentación: no carga ni guarda la memoria del jugador.
const GAME = preload("res://scenes/main.tscn")
var backdrop: Node2D
var _entering: bool = false

@onready var start_button: Button = $Interface/Screen/Margins/Columns/Menu/Start
@onready var quit_button: Button = $Interface/Screen/Margins/Columns/Menu/Quit
@onready var status: Label = $Interface/Screen/Margins/Columns/Menu/Status

func _ready() -> void:
	Engine.time_scale = 1.0
	backdrop = GAME.instantiate() as Node2D
	(backdrop.get_node("Entities/Cat") as Cat).persist_brain = false
	var cycle: DayNight = backdrop.get_node("DayNight") as DayNight
	cycle.start_hour = 16.5
	cycle.day_length_sec = 2400.0
	add_child(backdrop)
	(backdrop.get_node("HUD") as CanvasLayer).visible = false
	backdrop.set("_follow", false)
	backdrop.set_process(false)
	backdrop.set_process_unhandled_input(false)
	var cat: Cat = backdrop.get_node("Entities/Cat") as Cat
	cat.set_process(false)
	cat.pose = "sit"
	cat._apply_pose(0.0)
	_fit_background()
	get_viewport().size_changed.connect(_fit_background)
	start_button.pressed.connect(_enter_island)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	start_button.grab_focus()

func _fit_background() -> void:
	var island: Island = backdrop.get_node("Island") as Island
	var camera: Camera2D = backdrop.get_node("Camera2D") as Camera2D
	var size: Vector2 = get_viewport().get_visible_rect().size
	var low: Vector2 = Iso.to_screen(Vector2.ONE * float(island.map_size) * 0.5)
	var high: Vector2 = low
	for cell: Vector2i in island.land_cells:
		var point: Vector2 = Iso.to_screen(Vector2(cell))
		low.x = minf(low.x, point.x)
		low.y = minf(low.y, point.y)
		high.x = maxf(high.x, point.x)
		high.y = maxf(high.y, point.y)
	low -= Vector2(75, 120)
	high += Vector2(75, 70)
	var bounds: Vector2 = high - low
	var menu_width: float = 440.0
	var zoom_factor: float = minf(maxf(size.x - menu_width - 50.0, 200.0) / bounds.x, maxf(size.y - 100.0, 200.0) / bounds.y)
	camera.zoom = Vector2.ONE * zoom_factor
	camera.position = (low + high) * 0.5 - Vector2(menu_width * 0.5 / zoom_factor, 0)

func _enter_island() -> void:
	if _entering:
		return
	_entering = true
	start_button.disabled = true
	status.text = "La isla te espera…"
	var error: Error = get_tree().change_scene_to_file("res://scenes/main.tscn")
	if error != OK:
		_entering = false
		start_button.disabled = false
		status.text = "No se pudo abrir la isla. Intenta otra vez."
		push_error("Error al iniciar la isla: %s" % error_string(error))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event as InputEventKey
		if key.keycode == KEY_F11 or key.keycode == KEY_F:
			var fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()
