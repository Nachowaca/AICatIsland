@tool
class_name Fish
extends IsoEntity
## Pescado varado en la arena. Los cardúmenes son decorativos y no comestibles.

@export var nutrition: float = 45.0
@export var land_spot: Vector2 = Vector2.ZERO

var claimed: bool = false
var _t: float = 0.0
var _phase: float = 0.0


func _init() -> void:
	elevated = true


func _ready() -> void:
	add_to_group("fish")
	_phase = randf() * TAU
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Pequeña sombra sobre arena: ya no flota ni produce ondas circulares.
	draw_shadow(9.0, Vector2(0, 1), 0.22)
	var c: Vector2 = Vector2(0, -2)
	var tail: PackedVector2Array = PackedVector2Array([c + Vector2(-7, 0), c + Vector2(-13, -5), c + Vector2(-12, 0), c + Vector2(-13, 5)])
	draw_colored_polygon(tail, Color(0.32, 0.45, 0.62))
	draw_polyline(PackedVector2Array([tail[0], tail[1], tail[2], tail[3], tail[0]]), INK, 1.0)
	fill_ellipse(c, 9.0, 3.8, Color(0.78, 0.84, 0.9), 1.1)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -1), c + Vector2(-2, -3.6), c + Vector2(5, -3.2), c + Vector2(8, -0.5), c + Vector2(0, -1)]), Color(0.33, 0.47, 0.66))
	draw_circle(c + Vector2(5.5, -0.8), 1.1, INK)
	draw_line(c + Vector2(3, -1.5), c + Vector2(3, 2), Color(INK, 0.5), 0.8)
