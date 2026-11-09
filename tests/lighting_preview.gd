class_name LightingPreview
extends Node
## Vista fija para comparar iluminación sin tocar la memoria del gato.
@export var inspection_hour: float = 21.0

func _ready() -> void:
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node2D
	var cat: Cat = main.get_node("Entities/Cat") as Cat
	cat.persist_brain = false
	var cycle: DayNight = main.get_node("DayNight") as DayNight
	cycle.start_hour = inspection_hour
	cycle.day_length_sec = 100000.0
	add_child(main)
	main.set("_follow", false)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	camera.position = Iso.to_screen(Vector2(12.5, 11.0)) - Vector2(0, 25)
	camera.zoom = Vector2(3.0, 3.0)
