extends Node
## Vista previa ampliada de la isla (para revisar detalle de arte).

@export var zoom: float = 4.0
@export var grid_focus: Vector2 = Vector2(9.5, 19.5)
@export var follow_cat: bool = true
## Si no está vacío, fuerza esta pose del gato (para revisar animaciones).
@export var force_pose: String = ""


func _process(_delta: float) -> void:
	if force_pose != "":
		var cat: Cat = get_tree().get_first_node_in_group("cat") as Cat
		if cat:
			cat.set_process(false)  # congela el cerebro para revisar la pose
			cat.pose = force_pose
			cat._anim_t += _delta
			cat._apply_pose(0.0)
			cat.queue_redraw()


func _ready() -> void:
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node2D
	add_child(main)
	main.set("_follow", follow_cat)
	(main.get_node("HUD") as CanvasLayer).visible = false
	var cam: Camera2D = main.get_node("Camera2D") as Camera2D
	cam.zoom = Vector2(zoom, zoom)
	cam.position = Iso.to_screen(grid_focus) - Vector2(0, 10)
	for p: Node in main.get_node("HUD").get_children():
		(p as CanvasItem).visible = false
