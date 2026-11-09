extends Node
## Vista previa ampliada de la isla (para revisar detalle de arte).

@export var zoom: float = 2.6
@export var grid_focus: Vector2 = Vector2(9.5, 19.5)


func _ready() -> void:
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node2D
	add_child(main)
	main.set("_follow", false)
	(main.get_node("HUD") as CanvasLayer).visible = false
	var cam: Camera2D = main.get_node("Camera2D") as Camera2D
	cam.zoom = Vector2(zoom, zoom)
	cam.position = Iso.to_screen(grid_focus) - Vector2(0, 10)
	for p: Node in main.get_node("HUD").get_children():
		(p as CanvasItem).visible = false
