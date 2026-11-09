@tool
class_name Island
extends Node2D
## Isla procedural isométrica dibujada a mano con código (sin assets).
## Estilo inspirado en grabados ukiyo-e: tinta oscura en los bordes,
## olas en arco y colores planos.

enum T { DEEP, SHALLOW, SAND, GRASS, MOSS }

const LAND_H = 10.0
const INK = Color(0.16, 0.11, 0.1, 0.85)
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
## Altura "orgánica" de cada celda (antes de convertirla en tipo de suelo).
var elev: Dictionary = {}
var _tint: FastNoiseLite

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
	elev.clear()
	_tint = FastNoiseLite.new()
	_tint.seed = seed_value * 3 + 11
	_tint.frequency = 0.16
	_tint.fractal_octaves = 3
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.09
	# ruido de "tipo de costa": dónde hay playas anchas, estrechas o acantilado
	var beach: FastNoiseLite = FastNoiseLite.new()
	beach.seed = seed_value * 13 + 5
	beach.frequency = 0.09
	var c: Vector2 = Vector2(map_size, map_size) * 0.5
	for x in map_size:
		for y in map_size:
			var p: Vector2 = Vector2(x + 0.5, y + 0.5)
			var d: float = p.distance_to(c) / island_radius
			var h: float = 1.0 - d + noise.get_noise_2d(x, y) * 0.3
			var bw: float = beach.get_noise_2d(x, y) + 0.12
			var grass_th: float = 0.2 + maxf(bw, 0.0) * 0.55   # playas anchas
			if bw < -0.3:
				grass_th = 0.1                                  # acantilado de pasto
			var sand_th: float = 0.06 - maxf(bw, 0.0) * 0.2      # la arena avanza mar adentro
			var t: int = T.DEEP
			if h > 0.55:
				t = T.MOSS
			elif h > grass_th:
				t = T.GRASS
			elif h > sand_th:
				t = T.SAND
			elif h > -0.2:
				t = T.SHALLOW
			tiles[Vector2i(x, y)] = t
			elev[Vector2i(x, y)] = h
	_remove_grass_specks(4)
	_build_coast_field()
	# Reclasifica: la costa visible (campo suave) manda sobre las baldosas
	for cell: Vector2i in tiles:
		var t2: int = tiles[cell]
		if t2 >= T.GRASS:
			continue
		var s: float = sdf_at(Vector2(cell) + Vector2(0.5, 0.5))
		if s > 0.2:
			tiles[cell] = T.SAND
		elif s > -1.6:
			tiles[cell] = T.SHALLOW
		else:
			tiles[cell] = T.DEEP
	for cell2: Vector2i in tiles:
		if tiles[cell2] >= T.SAND:
			land_cells.append(cell2)
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, map_size, map_size)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for cell: Vector2i in tiles:
		_astar.set_point_solid(cell, not is_land_cell(cell))
	for cell: Vector2i in tiles:
		if tiles[cell] >= T.SAND:
			continue
		for dir: Vector2i in DIRS:
			if is_land_cell(cell + dir):
				shore_pairs.append([Vector2(cell) + Vector2(0.5, 0.5), Vector2(cell + dir) + Vector2(0.5, 0.5)])


## Los grupos de pasto muy pequeños parecen cajas sueltas: se vuelven arena.
func _remove_grass_specks(min_size: int) -> void:
	var seen: Dictionary = {}
	for start: Vector2i in tiles:
		if seen.has(start) or tiles[start] < T.GRASS:
			continue
		var comp: Array[Vector2i] = []
		var stack: Array[Vector2i] = [start]
		seen[start] = true
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			comp.append(c)
			for d: Vector2i in DIRS:
				var nb: Vector2i = c + d
				if not seen.has(nb) and tiles.get(nb, T.DEEP) >= T.GRASS:
					seen[nb] = true
					stack.append(nb)
		if comp.size() < min_size:
			for c2: Vector2i in comp:
				tiles[c2] = T.SAND


# ---------------------------------------------------------------- campo de costa

const FIELD_PAD = 8   # celdas de margen alrededor del mapa
const FIELD_RES = 6   # muestras por celda

## Distancia con signo a la línea de costa (en celdas): + tierra, − agua.
var coast_sdf: PackedFloat32Array = PackedFloat32Array()
## 1 donde hay pasto (para sombras del talud y reflejos en el shader).
var grass_mask: PackedFloat32Array = PackedFloat32Array()
var field_n: int = 0


func _chamfer(f: PackedFloat32Array, n: int) -> void:
	var d1: float = 1.0
	var d2: float = 1.4142
	for y in n:
		for x in n:
			var i: int = y * n + x
			var v: float = f[i]
			if v == 0.0:
				continue
			if x > 0: v = minf(v, f[i - 1] + d1)
			if y > 0:
				v = minf(v, f[i - n] + d1)
				if x > 0: v = minf(v, f[i - n - 1] + d2)
				if x < n - 1: v = minf(v, f[i - n + 1] + d2)
			f[i] = v
	for y in range(n - 1, -1, -1):
		for x in range(n - 1, -1, -1):
			var i: int = y * n + x
			var v: float = f[i]
			if v == 0.0:
				continue
			if x < n - 1: v = minf(v, f[i + 1] + d1)
			if y < n - 1:
				v = minf(v, f[i + n] + d1)
				if x < n - 1: v = minf(v, f[i + n + 1] + d2)
				if x > 0: v = minf(v, f[i + n - 1] + d2)
			f[i] = v


func _box_blur(f: PackedFloat32Array, n: int, r: int) -> PackedFloat32Array:
	var tmp: PackedFloat32Array = PackedFloat32Array()
	tmp.resize(n * n)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n * n)
	var w: float = 1.0 / float(2 * r + 1)
	for y in n:
		var acc: float = 0.0
		for k in range(-r, r + 1):
			acc += f[y * n + clampi(k, 0, n - 1)]
		for x in n:
			tmp[y * n + x] = acc * w
			acc += f[y * n + clampi(x + r + 1, 0, n - 1)] - f[y * n + clampi(x - r, 0, n - 1)]
	for x in n:
		var acc2: float = 0.0
		for k in range(-r, r + 1):
			acc2 += tmp[clampi(k, 0, n - 1) * n + x]
		for y in n:
			out[y * n + x] = acc2 * w
			acc2 += tmp[clampi(y + r + 1, 0, n - 1) * n + x] - tmp[clampi(y - r, 0, n - 1) * n + x]
	return out


## Construye la costa suave: distancia con signo a partir de las baldosas,
## suavizada (esquinas redondas) y deformada con ruido (bahías y puntas).
func _build_coast_field() -> void:
	var n: int = (map_size + FIELD_PAD * 2) * FIELD_RES
	field_n = n
	var inf: float = 1e9
	var out_d: PackedFloat32Array = PackedFloat32Array()
	var in_d: PackedFloat32Array = PackedFloat32Array()
	out_d.resize(n * n)
	in_d.resize(n * n)
	grass_mask.resize(n * n)
	for py in n:
		for px in n:
			var cell: Vector2i = Vector2i(floori(float(px) / FIELD_RES) - FIELD_PAD, floori(float(py) / FIELD_RES) - FIELD_PAD)
			var t: int = tiles.get(cell, T.DEEP)
			var i: int = py * n + px
			var land: bool = t >= T.SAND
			out_d[i] = 0.0 if land else inf
			in_d[i] = inf if land else 0.0
			grass_mask[i] = 1.0 if t >= T.GRASS else 0.0
	_chamfer(out_d, n)
	_chamfer(in_d, n)
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(n * n)
	for i in n * n:
		raw[i] = (in_d[i] - out_d[i]) / float(FIELD_RES)
	raw = _box_blur(_box_blur(raw, n, 3), n, 3)
	var warp: FastNoiseLite = FastNoiseLite.new()
	warp.seed = seed_value * 31 + 7
	warp.frequency = 0.4
	warp.fractal_octaves = 3
	coast_sdf.resize(n * n)
	for py in n:
		for px in n:
			var i: int = py * n + px
			var g: Vector2 = Vector2((float(px) + 0.5) / FIELD_RES - FIELD_PAD, (float(py) + 0.5) / FIELD_RES - FIELD_PAD)
			var s: float = raw[i]
			var near: float = 1.0 - smoothstep(1.5, 3.0, absf(s))
			s += warp.get_noise_2d(g.x, g.y) * 0.55 * near
			if grass_mask[i] > 0.5:
				s = maxf(s, 0.18)   # la costa nunca se mete bajo el pasto
			coast_sdf[i] = s


## Distancia con signo a la costa en un punto de rejilla (interpolada).
func sdf_at(g: Vector2) -> float:
	if field_n == 0:
		return 1.0 if is_land_cell(Vector2i(floori(g.x), floori(g.y))) else -1.0
	var fx: float = (g.x + FIELD_PAD) * FIELD_RES - 0.5
	var fy: float = (g.y + FIELD_PAD) * FIELD_RES - 0.5
	var x0: int = clampi(floori(fx), 0, field_n - 2)
	var y0: int = clampi(floori(fy), 0, field_n - 2)
	var tx: float = clampf(fx - float(x0), 0.0, 1.0)
	var ty: float = clampf(fy - float(y0), 0.0, 1.0)
	var i: int = y0 * field_n + x0
	var top: float = lerpf(coast_sdf[i], coast_sdf[i + 1], tx)
	var bot: float = lerpf(coast_sdf[i + field_n], coast_sdf[i + field_n + 1], tx)
	return lerpf(top, bot, ty)


## Punto sobre la línea entre a (tierra) y b (agua) donde la costa vale `target`.
func along_coast(land: Vector2, water: Vector2, target: float) -> Vector2:
	var best: Vector2 = land
	for k in 21:
		var p: Vector2 = land.lerp(water, float(k) / 20.0)
		if sdf_at(p) < target:
			return best
		best = p
	return best


## Para una pareja de orilla: [sitio en tierra para comer/mirar, sitio en el agua].
func shore_spots(pair: Array) -> Array:
	var water: Vector2 = pair[0]
	var land: Vector2 = pair[1]
	var on_land: Vector2 = along_coast(land, water, 0.3)
	var in_water: Vector2 = along_coast(land, water + (water - land) * 0.6, -0.3)
	return [on_land, in_water]


func tile_at(g: Vector2) -> int:
	return tiles.get(Vector2i(floori(g.x), floori(g.y)), T.DEEP)


func is_land_cell(c: Vector2i) -> bool:
	var t: int = tiles.get(c, T.DEEP)
	return t >= T.SAND


func is_walkable(g: Vector2) -> bool:
	if not is_land_cell(Vector2i(floori(g.x), floori(g.y))) and sdf_at(g) < 0.15:
		return false
	return sdf_at(g) > 0.12


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
		if not is_walkable(p):
			continue
		if near.x < 0.0 or p.distance_to(near) <= max_dist:
			return p
	return near


## Punto en tierra al borde del agua. Devuelve [punto_tierra, punto_agua].
func random_shore(rng: RandomNumberGenerator) -> Array:
	var pair: Array = shore_pairs[rng.randi() % shore_pairs.size()]
	return shore_spots(pair)


# ---------------------------------------------------------------- dibujo

func _p(x: float, y: float, h: float = 0.0) -> Vector2:
	return Iso.to_screen(Vector2(x, y)) - Vector2(0.0, h)


func _hash(x: int, y: int) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (seed_value * 83492791)
	return float(absi(h) % 1000) / 1000.0


## El agua la dibuja el nodo Water (shader); aquí solo la tierra.
## Las matas de pasto y flores las dibuja el nodo Meadow.
func _draw() -> void:
	for s in range(0, 2 * map_size - 1):
		for x in range(maxi(0, s - map_size + 1), mini(s, map_size - 1) + 1):
			_draw_tile(x, s - x)
	# segunda pasada: bordes festoneados del pasto (por encima de vecinos)
	for s2 in range(0, 2 * map_size - 1):
		for x2 in range(maxi(0, s2 - map_size + 1), mini(s2, map_size - 1) + 1):
			_draw_grass_lip(Vector2i(x2, s2 - x2))


# ---------------------------------------------------------------- color del pasto

const GRASS_LIGHT = Color(0.68, 0.78, 0.46)
const GRASS_MID = Color(0.53, 0.69, 0.38)
const GRASS_DEEP = Color(0.41, 0.59, 0.33)
const MOSS_A = Color(0.33, 0.51, 0.31)
const MOSS_B = Color(0.26, 0.43, 0.28)


## Altura orgánica interpolada entre centros de celda (para mezclas suaves).
func elev_at(g: Vector2) -> float:
	var p: Vector2 = g - Vector2(0.5, 0.5)
	var x0: int = floori(p.x)
	var y0: int = floori(p.y)
	var fx: float = p.x - float(x0)
	var fy: float = p.y - float(y0)
	var a: float = float(elev.get(Vector2i(x0, y0), -1.0))
	var b: float = float(elev.get(Vector2i(x0 + 1, y0), -1.0))
	var c: float = float(elev.get(Vector2i(x0, y0 + 1), -1.0))
	var d: float = float(elev.get(Vector2i(x0 + 1, y0 + 1), -1.0))
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## Color del pasto en cualquier punto: manchas suaves tipo aguada de tinta
## y paso gradual hacia el musgo del centro de la isla.
func grass_color(g: Vector2) -> Color:
	if _tint == null:
		return GRASS_MID
	var n: float = _tint.get_noise_2d(g.x * 6.0, g.y * 6.0) * 0.5 + 0.5
	var fine: float = _tint.get_noise_2d(g.x * 22.0 + 100.0, g.y * 22.0) * 0.5 + 0.5
	var col: Color
	if n < 0.5:
		col = GRASS_DEEP.lerp(GRASS_MID, smoothstep(0.15, 0.5, n))
	else:
		col = GRASS_MID.lerp(GRASS_LIGHT, smoothstep(0.5, 0.85, n))
	var moss: float = smoothstep(0.42, 0.72, elev_at(g))
	col = col.lerp(MOSS_A.lerp(MOSS_B, 1.0 - n), moss * 0.85)
	return col.lightened((fine - 0.5) * 0.08)


## Ceja de pasto festoneada (como nubes de grabado) que cuelga sobre el
## escalón hacia la arena o el agua. Rompe la escalera de baldosas.
func _draw_grass_lip(cell: Vector2i) -> void:
	var t: int = tiles.get(cell, T.DEEP)
	if t < T.GRASS:
		return
	var h: float = LAND_H
	var fx: float = float(cell.x)
	var fy: float = float(cell.y)
	for dir: Vector2i in DIRS:
		if cell_height(cell + dir) >= h:
			continue
		var a: Vector2
		var b: Vector2
		match dir:
			Vector2i(1, 0):
				a = Vector2(fx + 1, fy)
				b = Vector2(fx + 1, fy + 1)
			Vector2i(-1, 0):
				a = Vector2(fx, fy)
				b = Vector2(fx, fy + 1)
			Vector2i(0, 1):
				a = Vector2(fx, fy + 1)
				b = Vector2(fx + 1, fy + 1)
			_:
				a = Vector2(fx, fy)
				b = Vector2(fx + 1, fy)
		var n: Vector2 = Vector2(dir)
		var front: bool = dir.x > 0 or dir.y > 0
		var bumps: int = 3 + int(_hash(cell.x * 7 + dir.x, cell.y * 5 + dir.y) * 2.0)
		for i in bumps:
			var t0: float = float(i) / float(bumps)
			var t1: float = float(i + 1) / float(bumps)
			var depth: float = 0.06 + 0.11 * _hash(cell.x * 13 + i, cell.y * 17 + dir.x * 3 + dir.y)
			var arc: PackedVector2Array = PackedVector2Array()
			for k in 9:
				var ang: float = PI * float(k) / 8.0
				var along: float = lerpf(t0, t1, (1.0 - cos(ang)) * 0.5)
				var gpt: Vector2 = a.lerp(b, along) + n * depth * sin(ang)
				arc.append(_p(gpt.x, gpt.y, h))
			var mid: Vector2 = a.lerp(b, (t0 + t1) * 0.5)
			var col: Color = grass_color(mid - n * 0.2)
			if front:
				var shadow: PackedVector2Array = PackedVector2Array()
				for p: Vector2 in arc:
					shadow.append(p + Vector2(0, 3))
				draw_colored_polygon(shadow, Color(0.12, 0.1, 0.05, 0.22))
			draw_colored_polygon(arc, col)
			draw_polyline(arc, Color(INK, 0.7), 1.1)
			# brizna que asoma del borde
			if _hash(cell.x + i * 3, cell.y + dir.y * 7) > 0.6:
				var tip: Vector2 = arc[4]
				draw_line(tip, tip + Vector2(n.x - n.y, -3.5), col.darkened(0.3), 1.0)


## La playa está a nivel del mar (la dibuja el shader del agua); el pasto
## forma un pequeño talud de LAND_H píxeles sobre ella.
func cell_height(c: Vector2i) -> float:
	var t: int = tiles.get(c, T.DEEP)
	if t >= T.GRASS:
		return LAND_H
	return 0.0


## Altura del suelo (px) en una posición de rejilla; la usan las entidades.
func height_at(g: Vector2) -> float:
	return cell_height(Vector2i(floori(g.x), floori(g.y)))


func _draw_tile(x: int, y: int) -> void:
	var cell: Vector2i = Vector2i(x, y)
	var t: int = tiles[cell]
	if t < T.GRASS:
		return # la arena y el agua las pinta el shader del mar
	var j: float = _hash(x, y)
	var fx: float = float(x)
	var fy: float = float(y)
	var h: float = LAND_H
	var side_l: Color = EARTH_L
	var side_r: Color = EARTH_R
	var h_y: float = cell_height(cell + Vector2i(0, 1))
	var h_x: float = cell_height(cell + Vector2i(1, 0))
	var water_y: bool = sdf_at(Vector2(fx + 0.5, fy + 1.15)) < 0.0
	var water_x: bool = sdf_at(Vector2(fx + 1.15, fy + 0.5)) < 0.0
	# talud de tierra visible (caras +y y +x) con estratos y raíces
	if h_y < h:
		draw_colored_polygon(PackedVector2Array([_p(fx, fy + 1, h), _p(fx + 1, fy + 1, h), _p(fx + 1, fy + 1, h_y), _p(fx, fy + 1, h_y)]), side_l)
		draw_line(_p(fx, fy + 1, 4.0 + j * 2.0), _p(fx + 1, fy + 1, 4.5 + j), side_l.darkened(0.15), 1.0)
		if water_y:
			draw_colored_polygon(PackedVector2Array([_p(fx, fy + 1, 2.5), _p(fx + 1, fy + 1, 2.5), _p(fx + 1, fy + 1), _p(fx, fy + 1)]), side_l.darkened(0.35))
	if h_x < h:
		draw_colored_polygon(PackedVector2Array([_p(fx + 1, fy + 1, h), _p(fx + 1, fy, h), _p(fx + 1, fy, h_x), _p(fx + 1, fy + 1, h_x)]), side_r)
		draw_line(_p(fx + 1, fy, 4.5 + j), _p(fx + 1, fy + 1, 4.0 + j * 2.0), side_r.darkened(0.15), 1.0)
		if water_x:
			draw_colored_polygon(PackedVector2Array([_p(fx + 1, fy + 1, 2.5), _p(fx + 1, fy, 2.5), _p(fx + 1, fy), _p(fx + 1, fy + 1)]), side_r.darkened(0.35))
	# pasto: 2x2 sub-quads con color por vértice → degradados suaves sin damero
	for sx in 2:
		for sy in 2:
			var x0: float = fx + float(sx) * 0.5
			var y0: float = fy + float(sy) * 0.5
			var corners: Array[Vector2] = [Vector2(x0, y0), Vector2(x0 + 0.5, y0), Vector2(x0 + 0.5, y0 + 0.5), Vector2(x0, y0 + 0.5)]
			var pts: PackedVector2Array = PackedVector2Array()
			var cols: PackedColorArray = PackedColorArray()
			for cg: Vector2 in corners:
				pts.append(_p(cg.x, cg.y, h))
				cols.append(grass_color(cg))
			draw_polygon(pts, cols)
	# tinta en la base del talud
	if h_y < h:
		draw_line(_p(fx, fy + 1, 0), _p(fx + 1, fy + 1, 0), Color(INK, 0.55), 1.0)
	if h_x < h:
		draw_line(_p(fx + 1, fy, 0), _p(fx + 1, fy + 1, 0), Color(INK, 0.55), 1.0)
	# piedra musgosa ocasional
	var c: Vector2 = _p(fx + 0.5, fy + 0.5, h)
	if t == T.MOSS and j < 0.08:
		draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-3, -4), c + Vector2(4, -4), c + Vector2(7, 0), c + Vector2(2, 2)]), Color(0.55, 0.55, 0.52))
