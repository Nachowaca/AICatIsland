@tool
class_name Water
extends Node2D
## Mar procedural. Calcula un campo de distancia a la costa a partir de la
## isla y se lo pasa al shader res://shaders/water.gdshader.

const SHADER = preload("res://shaders/water.gdshader")
const PAD = 8          # celdas de margen alrededor del mapa
const RES = 6          # píxeles de textura por celda
const MAX_DIST = 8.0   # distancia máxima codificada (celdas)
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


func _rebuild() -> void:
	if _island == null or _mat == null:
		return
	var span: int = _island.map_size + PAD * 2
	var n: int = span * RES
	var inf: float = 1e9
	var field: PackedFloat32Array = PackedFloat32Array()
	field.resize(n * n)
	for py in n:
		for px in n:
			var cell: Vector2i = Vector2i(floori(float(px) / RES) - PAD, floori(float(py) / RES) - PAD)
			field[py * n + px] = 0.0 if _island.is_land_cell(cell) else inf
	# transformada de distancia por chaflán (dos pasadas)
	var d1: float = 1.0
	var d2: float = 1.4142
	for y in n:
		for x in n:
			var i: int = y * n + x
			var v: float = field[i]
			if v == 0.0:
				continue
			if x > 0: v = minf(v, field[i - 1] + d1)
			if y > 0:
				v = minf(v, field[i - n] + d1)
				if x > 0: v = minf(v, field[i - n - 1] + d2)
				if x < n - 1: v = minf(v, field[i - n + 1] + d2)
			field[i] = v
	for y in range(n - 1, -1, -1):
		for x in range(n - 1, -1, -1):
			var i: int = y * n + x
			var v: float = field[i]
			if v == 0.0:
				continue
			if x < n - 1: v = minf(v, field[i + 1] + d1)
			if y < n - 1:
				v = minf(v, field[i + n] + d1)
				if x < n - 1: v = minf(v, field[i + n + 1] + d2)
				if x > 0: v = minf(v, field[i + n - 1] + d2)
			field[i] = v
	var norm: PackedFloat32Array = PackedFloat32Array()
	norm.resize(n * n)
	for i in n * n:
		norm[i] = clampf(field[i] / float(RES) / MAX_DIST, 0.0, 1.0)
	var img: Image = Image.create_from_data(n, n, false, Image.FORMAT_RF, norm.to_byte_array())
	_mat.set_shader_parameter("dist_tex", ImageTexture.create_from_image(img))
	_mat.set_shader_parameter("grid_span", float(span))
	_mat.set_shader_parameter("grid_pad", float(PAD))
	_mat.set_shader_parameter("max_dist", MAX_DIST)
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
