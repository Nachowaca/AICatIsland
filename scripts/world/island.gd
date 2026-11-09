@tool
class_name Island
extends Node2D
## Isla procedural isométrica dibujada a mano con código (sin assets).
## Estilo inspirado en grabados ukiyo-e: tinta oscura en los bordes,
## olas en arco y colores planos.

enum T { DEEP, SHALLOW, SAND, GRASS, MOSS }

const LAND_H = 10.0
const SAND_H = 4.0
const INK = Color(0.16, 0.11, 0.1, 0.85)
const SAND_COL = Color(0.94, 0.85, 0.64)
const SAND_SIDE_L = Color(0.8, 0.67, 0.46)
const SAND_SIDE_R = Color(0.7, 0.57, 0.38)
const GRASS_COL = Color(0.5, 0.69, 0.37)
const GRASS_COL2 = Color(0.58, 0.74, 0.4)
const MOSS_COL = Color(0.36, 0.55, 0.32)
const EARTH_L = Color(0.55, 0.4, 0.27)
const EARTH_R = Color(0.45, 0.32, 0.21)
const DIRS = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

@export var map_size: int = 26:
	set(v):
		map_size = clampi(v, 8, 64)
		_regen()
@export var island_radius: float = 9.0:
	set(v):
		island_radius = v
		_regen()
@export var seed_value: int = 7:
	set(v):
		seed_value = v
		_regen()

var tiles: Dictionary = {}
var land_cells: Array[Vector2i] = []
## Cada elemento: [Vector2 centro_agua, Vector2 centro_tierra]
var shore_pairs: Array = []
var _astar: AStarGrid2D

## Isla activa, para que las entidades sepan a qué altura está el suelo.
static var instance: Island

signal regenerated


func _enter_tree() -> void:
	instance = self
	if tiles.is_empty():
		generate()


func _ready() -> void:
	add_to_group("island")
	_regen()


func _regen() -> void:
	generate()
	queue_redraw()
	regenerated.emit()


func generate() -> void:
	tiles.clear()
	land_cells.clear()
	shore_pairs.clear()
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.09
	var c: Vector2 = Vector2(map_size, map_size) * 0.5
	for x in map_size:
		for y in map_size:
			var p: Vector2 = Vector2(x + 0.5, y + 0.5)
			var d: float = p.distance_to(c) / island_radius
			var h: float = 1.0 - d + noise.get_noise_2d(x, y) * 0.3
			var t: int = T.DEEP
			if h > 0.55:
				t = T.MOSS
			elif h > 0.2:
				t = T.GRASS
			elif h > 0.06:
				t = T.SAND
			elif h > -0.2:
				t = T.SHALLOW
			tiles[Vector2i(x, y)] = t
			if t >= T.SAND:
				land_cells.append(Vector2i(x, y))
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, map_size, map_size)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for cell: Vector2i in tiles:
		_astar.set_point_solid(cell, not is_land_cell(cell))
	for cell: Vector2i in tiles:
		if tiles[cell] != T.SHALLOW:
			continue
		for dir: Vector2i in DIRS:
			if is_land_cell(cell + dir):
				shore_pairs.append([Vector2(cell) + Vector2(0.5, 0.5), Vector2(cell + dir) + Vector2(0.5, 0.5)])


func tile_at(g: Vector2) -> int:
	return tiles.get(Vector2i(floori(g.x), floori(g.y)), T.DEEP)


func is_land_cell(c: Vector2i) -> bool:
	var t: int = tiles.get(c, T.DEEP)
	return t >= T.SAND


func is_walkable(g: Vector2) -> bool:
	return is_land_cell(Vector2i(floori(g.x), floori(g.y)))


## Camino por tierra (centros de celda) terminando exactamente en `to`.
func find_path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var a: Vector2i = Vector2i(floori(from.x), floori(from.y))
	var b: Vector2i = Vector2i(floori(to.x), floori(to.y))
	if _astar and is_land_cell(a) and is_land_cell(b) and a != b:
		var ids: Array[Vector2i] = _astar.get_id_path(a, b)
		for i in range(1, ids.size() - 1):
			out.append(Vector2(ids[i]) + Vector2(0.5, 0.5))
	out.append(to)
	return out


func nearest_land(g: Vector2) -> Vector2:
	var best: Vector2 = g
	var bd: float = INF
	for c: Vector2i in land_cells:
		var p: Vector2 = Vector2(c) + Vector2(0.5, 0.5)
		var d: float = p.distance_squared_to(g)
		if d < bd:
			bd = d
			best = p
	return best


func random_land_point(rng: RandomNumberGenerator, near: Vector2 = Vector2(-1, -1), max_dist: float = 999.0) -> Vector2:
	for i in 40:
		var cell: Vector2i = land_cells[rng.randi() % land_cells.size()]
		var p: Vector2 = Vector2(cell) + Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8))
		if near.x < 0.0 or p.distance_to(near) <= max_dist:
			return p
	return near


## Punto en tierra al borde del agua. Devuelve [punto_tierra, punto_agua].
func random_shore(rng: RandomNumberGenerator) -> Array:
	var pair: Array = shore_pairs[rng.randi() % shore_pairs.size()]
	var water: Vector2 = pair[0]
	var land: Vector2 = pair[1]
	return [land.lerp(water, 0.3), water]


# ---------------------------------------------------------------- dibujo

func _p(x: float, y: float, h: float = 0.0) -> Vector2:
	return Iso.to_screen(Vector2(x, y)) - Vector2(0.0, h)


func _hash(x: int, y: int) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (seed_value * 83492791)
	return float(absi(h) % 1000) / 1000.0


## El agua la dibuja el nodo Water (shader); aquí solo la tierra.
func _draw() -> void:
	for s in range(0, 2 * map_size - 1):
		for x in range(maxi(0, s - map_size + 1), mini(s, map_size - 1) + 1):
			_draw_tile(x, s - x)


func cell_height(c: Vector2i) -> float:
	var t: int = tiles.get(c, T.DEEP)
	if t == T.SAND:
		return SAND_H
	if t >= T.GRASS:
		return LAND_H
	return 0.0


## Altura del suelo (px) en una posición de rejilla; la usan las entidades.
func height_at(g: Vector2) -> float:
	var h: float = cell_height(Vector2i(floori(g.x), floori(g.y)))
	return h if h > 0.0 else SAND_H


func _draw_tile(x: int, y: int) -> void:
	var cell: Vector2i = Vector2i(x, y)
	var t: int = tiles[cell]
	if t < T.SAND:
		return
	var j: float = _hash(x, y)
	var fx: float = float(x)
	var fy: float = float(y)

	var h: float = cell_height(cell)
	var top: Color
	var side_l: Color = EARTH_L
	var side_r: Color = EARTH_R
	match t:
		T.SAND:
			top = SAND_COL.lerp(Color(0.98, 0.9, 0.72), j * 0.4)
			side_l = SAND_SIDE_L
			side_r = SAND_SIDE_R
		T.GRASS:
			top = GRASS_COL.lerp(GRASS_COL2, j * 0.6)
		_:
			top = MOSS_COL.lerp(GRASS_COL, j * 0.25)

	var ink: Color = Color(INK, 0.45) if t == T.SAND else INK
	var h_y: float = cell_height(cell + Vector2i(0, 1))
	var h_x: float = cell_height(cell + Vector2i(1, 0))
	# caras laterales visibles (hacia +y y +x) desde la altura del vecino
	if h_y < h:
		draw_colored_polygon(PackedVector2Array([_p(fx, fy + 1, h), _p(fx + 1, fy + 1, h), _p(fx + 1, fy + 1, h_y), _p(fx, fy + 1, h_y)]), side_l)
		if h_y == 0.0:
			# franja mojada en la base, donde rompe el agua
			draw_colored_polygon(PackedVector2Array([_p(fx, fy + 1, 2.0), _p(fx + 1, fy + 1, 2.0), _p(fx + 1, fy + 1), _p(fx, fy + 1)]), side_l.darkened(0.3))
	if h_x < h:
		draw_colored_polygon(PackedVector2Array([_p(fx + 1, fy + 1, h), _p(fx + 1, fy, h), _p(fx + 1, fy, h_x), _p(fx + 1, fy + 1, h_x)]), side_r)
		if h_x == 0.0:
			draw_colored_polygon(PackedVector2Array([_p(fx + 1, fy + 1, 2.0), _p(fx + 1, fy, 2.0), _p(fx + 1, fy), _p(fx + 1, fy + 1)]), side_r.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([_p(fx, fy, h), _p(fx + 1, fy, h), _p(fx + 1, fy + 1, h), _p(fx, fy + 1, h)]), top)

	# Arena mojada: franjas más oscuras en los bordes que tocan el agua
	if t == T.SAND:
		var wet: Color = Color(0.62, 0.52, 0.36, 0.28)
		var wet2: Color = Color(0.55, 0.45, 0.3, 0.32)
		for dir: Vector2i in DIRS:
			if is_land_cell(cell + dir):
				continue
			for band: Array in [[0.32, wet], [0.14, wet2]]:
				var w: float = band[0]
				var poly: PackedVector2Array
				match dir:
					Vector2i(0, 1):
						poly = PackedVector2Array([_p(fx, fy + 1, h), _p(fx + 1, fy + 1, h), _p(fx + 1, fy + 1 - w, h), _p(fx, fy + 1 - w, h)])
					Vector2i(0, -1):
						poly = PackedVector2Array([_p(fx, fy, h), _p(fx + 1, fy, h), _p(fx + 1, fy + w, h), _p(fx, fy + w, h)])
					Vector2i(1, 0):
						poly = PackedVector2Array([_p(fx + 1, fy, h), _p(fx + 1, fy + 1, h), _p(fx + 1 - w, fy + 1, h), _p(fx + 1 - w, fy, h)])
					_:
						poly = PackedVector2Array([_p(fx, fy, h), _p(fx, fy + 1, h), _p(fx + w, fy + 1, h), _p(fx + w, fy, h)])
				draw_colored_polygon(poly, band[1])

	# Bordes de tinta donde el terreno baja
	if h_y < h:
		draw_line(_p(fx, fy + 1, h), _p(fx + 1, fy + 1, h), ink, 1.2)
		draw_line(_p(fx, fy + 1, h_y), _p(fx + 1, fy + 1, h_y), ink, 1.0)
	if h_x < h:
		draw_line(_p(fx + 1, fy, h), _p(fx + 1, fy + 1, h), ink, 1.2)
		draw_line(_p(fx + 1, fy, h_x), _p(fx + 1, fy + 1, h_x), ink, 1.0)
	if cell_height(cell + Vector2i(-1, 0)) < h:
		draw_line(_p(fx, fy, h), _p(fx, fy + 1, h), ink, 1.2)
	if cell_height(cell + Vector2i(0, -1)) < h:
		draw_line(_p(fx, fy, h), _p(fx + 1, fy, h), ink, 1.2)

	# Detalles
	var c: Vector2 = _p(fx + 0.5, fy + 0.5, h)
	if t == T.GRASS or t == T.MOSS:
		if j > 0.45:
			var tuft: Color = top.darkened(0.25)
			var o: Vector2 = Vector2((j - 0.7) * 30.0, (_hash(y, x) - 0.5) * 10.0)
			draw_line(c + o, c + o + Vector2(-2, -4), tuft, 1.2)
			draw_line(c + o, c + o + Vector2(0, -5), tuft, 1.2)
			draw_line(c + o, c + o + Vector2(2, -4), tuft, 1.2)
		if j > 0.9:
			var o2: Vector2 = Vector2((_hash(y, x) - 0.5) * 24.0, (j - 0.95) * 60.0)
			draw_circle(c + o2, 1.6, Color(1.0, 0.8, 0.86))
			draw_circle(c + o2 + Vector2(5, 2), 1.4, Color(1.0, 0.97, 0.9))
		if t == T.MOSS and j < 0.08:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-3, -4), c + Vector2(4, -4), c + Vector2(7, 0), c + Vector2(2, 2)]), Color(0.55, 0.55, 0.52))
	elif t == T.SAND and j > 0.82:
		draw_circle(c + Vector2((j - 0.9) * 80.0, 2), 1.5, Color(0.7, 0.66, 0.6))
		draw_circle(c + Vector2((j - 0.9) * 80.0 + 4, 3), 1.0, Color(0.95, 0.75, 0.7))

