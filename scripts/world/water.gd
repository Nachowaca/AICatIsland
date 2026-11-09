@tool
class_name Water
extends Node2D
## Mar procedural. Calcula un campo de distancia a la costa a partir de la
## isla y se lo pasa al shader res://shaders/water.gdshader.

const SHADER = preload("res://shaders/water.gdshader")
const EXTENT = 40.0    # cuánto mar dibujar alrededor (celdas)

@export var island_path: NodePath = ^"../Island"

var _mat: ShaderMaterial
var _island: Island
var _day_night: Node


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	_island = get_node_or_null(island_path) as Island
	if _island:
		if not _island.regenerated.is_connected(_rebuild):
			_island.regenerated.connect(_rebuild)
	_rebuild()
	set_process(not Engine.is_editor_hint())


func _process(_delta: float) -> void:
	if _day_night == null:
		_day_night = get_tree().get_first_node_in_group("day_night")
	if _day_night and _day_night.has_method("night_factor"):
		_mat.set_shader_parameter("night", _day_night.night_factor())


## Pasa al shader la costa suave de la isla (R = distancia con signo,
## G = máscara de pasto) como textura flotante.
func _rebuild() -> void:
	if _island == null or _mat == null or _island.field_n == 0:
		return
	var n: int = _island.field_n
	var data: PackedFloat32Array = PackedFloat32Array()
	data.resize(n * n * 2)
	for i in n * n:
		data[i * 2] = _island.coast_sdf[i]
		data[i * 2 + 1] = _island.grass_mask[i]
	var img: Image = Image.create_from_data(n, n, false, Image.FORMAT_RGF, data.to_byte_array())
	_mat.set_shader_parameter("field_tex", ImageTexture.create_from_image(img))
	_mat.set_shader_parameter("grid_span", float(_island.map_size + Island.FIELD_PAD * 2))
	_mat.set_shader_parameter("grid_pad", float(Island.FIELD_PAD))
	queue_redraw()


func _draw() -> void:
	if _island == null:
		return
	var m: float = float(_island.map_size)
	var pts: PackedVector2Array = PackedVector2Array([
		Iso.to_screen(Vector2(-EXTENT, -EXTENT)), Iso.to_screen(Vector2(m + EXTENT, -EXTENT)),
		Iso.to_screen(Vector2(m + EXTENT, m + EXTENT)), Iso.to_screen(Vector2(-EXTENT, m + EXTENT)),
	])
	draw_colored_polygon(pts, Color.WHITE)
