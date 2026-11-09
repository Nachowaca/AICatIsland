@tool
class_name ShoreDecor
extends Node2D
## Vida de playa: rocas con espuma en el agua, algas y maderas que trae la
## marea, conchas y estrellas de mar. Se coloca sola siguiendo la costa.

const INK = Color(0.16, 0.11, 0.1)

@export var island_path: NodePath = ^"../Island"
@export var rock_count: int = 7
@export var beach_items: int = 14

var _island: Island
var _rocks: Array = []   # [Vector2 pos_pantalla, float tamaño, int semilla]
var _items: Array = []   # [String tipo, Vector2 pos_pantalla, float ángulo, int semilla]
var _t: float = 0.0


func _ready() -> void:
	_island = get_node_or_null(island_path) as Island
	if _island and not _island.regenerated.is_connected(_place):
		_island.regenerated.connect(_place)
	_place()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _place() -> void:
	_rocks.clear()
	_items.clear()
	if _island == null or _island.shore_pairs.is_empty():
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _island.seed_value * 977 + 13
	var used: Array[Vector2] = []
	# rocas: medio sumergidas, un poco mar adentro
	var tries: int = 0
	while _rocks.size() < rock_count and tries < 200:
		tries += 1
		var pair: Array = _island.shore_pairs[rng.randi() % _island.shore_pairs.size()]
		var land: Vector2 = pair[1]
		var water: Vector2 = pair[0]
		var g: Vector2 = _island.along_coast(land, water + (water - land) * 1.2, -rng.randf_range(0.25, 0.7))
		g += Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
		if _too_close(g, used, 2.2):
			continue
		used.append(g)
		_rocks.append([Iso.to_screen(g), rng.randf_range(0.7, 1.25), rng.randi()])
	# objetos sobre la arena
	tries = 0
	while _items.size() < beach_items and tries < 400:
		tries += 1
		var cell: Vector2i = _island.land_cells[rng.randi() % _island.land_cells.size()]
		if _island.tiles[cell] != Island.T.SAND:
			continue
		var g2: Vector2 = Vector2(cell) + Vector2(rng.randf(), rng.randf())
		var s: float = _island.sdf_at(g2)
		if s < 0.15 or _too_close(g2, used, 1.1):
			continue
		var kind: String
		if s < 0.75:
			kind = ["seaweed", "seaweed", "shell", "starfish"][rng.randi() % 4]
		else:
			kind = ["driftwood", "shell", "starfish", "stones"][rng.randi() % 4]
		used.append(g2)
		_items.append([kind, Iso.to_screen(g2), rng.randf_range(-0.6, 0.6), rng.randi()])
	_items.sort_custom(func(a: Array, b: Array) -> bool: return (a[1] as Vector2).y < (b[1] as Vector2).y)
	_rocks.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).y < (b[0] as Vector2).y)
	queue_redraw()


func _too_close(g: Vector2, used: Array[Vector2], min_d: float) -> bool:
	for u: Vector2 in used:
		if u.distance_to(g) < min_d:
			return true
	return false


func _ellipse(c: Vector2, rx: float, ry: float, n: int = 14) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _draw() -> void:
	for it: Array in _items:
		match it[0]:
			"seaweed":
				_seaweed(it[1], it[2], it[3])
			"shell":
				_shell(it[1], it[2])
			"starfish":
				_starfish(it[1], it[2])
			"driftwood":
				_driftwood(it[1], it[2])
			"stones":
				_stones(it[1], it[3])
	for r: Array in _rocks:
		_rock(r[0], r[1], r[2])


func _rock(p: Vector2, s: float, seed_i: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_i
	# anillos de espuma que laten con las olas
	for k in 2:
		var ph: float = fmod(_t * 0.35 + float(k) * 0.5 + float(seed_i % 7) * 0.13, 1.0)
		var ring: PackedVector2Array = _ellipse(p + Vector2(0, 1), (13.0 + ph * 10.0) * s, (6.0 + ph * 5.0) * s, 22)
		ring.append(ring[0])
		draw_polyline(ring, Color(1, 1, 1, 0.55 * (1.0 - ph)), 1.3)
	# reflejo oscuro en el agua
	draw_colored_polygon(_ellipse(p + Vector2(0, 2), 12.0 * s, 5.0 * s), Color(0.03, 0.12, 0.2, 0.35))
	var n: int = rng.randi_range(2, 3)
	for i in n:
		var o: Vector2 = Vector2(rng.randf_range(-7, 7), rng.randf_range(-1, 2)) * s
		var w: float = rng.randf_range(6.0, 10.0) * s
		var h: float = rng.randf_range(6.0, 11.0) * s
		var c: Vector2 = p + o
		var body: PackedVector2Array = PackedVector2Array([
			c + Vector2(-w, 1), c + Vector2(-w * 0.8, -h * 0.6), c + Vector2(-w * 0.2, -h), c + Vector2(w * 0.5, -h * 0.85),
			c + Vector2(w, -h * 0.25), c + Vector2(w * 0.9, 1.5)])
		draw_colored_polygon(body, Color(0.42, 0.43, 0.44))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-w * 0.7, -h * 0.55), c + Vector2(-w * 0.2, -h * 0.95), c + Vector2(w * 0.4, -h * 0.8), c + Vector2(-w * 0.05, -h * 0.45)]), Color(0.58, 0.59, 0.58))
		# franja mojada y algas en la línea de flotación
		draw_colored_polygon(PackedVector2Array([c + Vector2(-w, 1), c + Vector2(-w * 0.95, -2.5 * s), c + Vector2(w * 0.95, -2.0 * s), c + Vector2(w * 0.9, 1.5)]), Color(0.24, 0.3, 0.26))
		body.append(body[0])
		draw_polyline(body, INK, 1.2)
	# espuma que lame la base
	var lap: float = 0.5 + 0.5 * sin(_t * 1.6 + float(seed_i % 11))
	draw_colored_polygon(_ellipse(p + Vector2(0, 2), (11.0 + lap * 3.0) * s, 2.2 * s), Color(1, 1, 1, 0.65))


func _seaweed(p: Vector2, ang: float, seed_i: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_i
	for i in rng.randi_range(3, 5):
		var start: Vector2 = p + Vector2(rng.randf_range(-4, 4), rng.randf_range(-1, 1))
		var dir: Vector2 = Vector2(cos(ang + rng.randf_range(-0.8, 0.8)), sin(ang) * 0.5)
		var pts: PackedVector2Array = PackedVector2Array()
		for k in 5:
			pts.append(start + dir * float(k) * 2.4 + Vector2(0, sin(float(k) * 1.7 + float(i)) * 1.0))
		draw_polyline(pts, Color(0.22, 0.32, 0.18), 1.6)
		draw_polyline(pts, Color(0.36, 0.45, 0.22), 0.8)


func _shell(p: Vector2, ang: float) -> void:
	draw_set_transform(p, ang * 0.5, Vector2.ONE)
	var fan: PackedVector2Array = PackedVector2Array([Vector2(0, 1.5)])
	for i in 7:
		var a: float = PI + PI * float(i) / 6.0
		fan.append(Vector2(cos(a) * 3.2, sin(a) * 2.6))
	draw_colored_polygon(fan, Color(1.0, 0.9, 0.86))
	fan.append(fan[0])
	draw_polyline(fan, Color(INK, 0.6), 0.8)
	draw_line(Vector2(0, 1.5), Vector2(0, -2.2), Color(0.9, 0.62, 0.6), 0.7)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _starfish(p: Vector2, ang: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 10:
		var a: float = ang + TAU * float(i) / 10.0
		var r: float = 4.2 if i % 2 == 0 else 1.7
		pts.append(p + Vector2(cos(a) * r, sin(a) * r * 0.6))
	draw_colored_polygon(pts, Color(0.95, 0.52, 0.32))
	pts.append(pts[0])
	draw_polyline(pts, Color(INK, 0.7), 0.9)
	draw_circle(p, 0.7, Color(1.0, 0.8, 0.6))


func _driftwood(p: Vector2, ang: float) -> void:
	var dir: Vector2 = Vector2(cos(ang), sin(ang) * 0.5).normalized()
	var a: Vector2 = p - dir * 9.0
	var b: Vector2 = p + dir * 9.0
	draw_colored_polygon(_ellipse(p + Vector2(1, 2), 10.0, 2.0), Color(0.3, 0.25, 0.15, 0.2))
	draw_line(a, b, INK, 4.4)
	draw_line(a, b, Color(0.78, 0.7, 0.58), 3.0)
	draw_line(a + Vector2(2, -0.6), b - Vector2(3, 0.6), Color(0.9, 0.84, 0.74), 0.8)
	var twig: Vector2 = p + dir * 3.0
	draw_line(twig, twig + Vector2(dir.y, -dir.x) * -5.0 + dir * 2.0, INK, 2.2)
	draw_line(twig, twig + Vector2(dir.y, -dir.x) * -5.0 + dir * 2.0, Color(0.78, 0.7, 0.58), 1.2)


func _stones(p: Vector2, seed_i: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_i
	for i in rng.randi_range(2, 4):
		var c: Vector2 = p + Vector2(rng.randf_range(-5, 5), rng.randf_range(-2, 2))
		var r: float = rng.randf_range(1.4, 2.6)
		var col: Color = [Color(0.6, 0.6, 0.62), Color(0.72, 0.66, 0.6), Color(0.5, 0.52, 0.5)][i % 3]
		draw_colored_polygon(_ellipse(c, r, r * 0.65, 10), col)
		draw_arc(c + Vector2(-0.4, -0.4), r * 0.55, PI, PI * 1.6, 5, Color(1, 1, 1, 0.5), 0.7)
