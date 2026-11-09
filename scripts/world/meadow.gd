@tool
class_name Meadow
extends Node2D
## Pradera: matas de pasto, susuki (juncos plateados), flores silvestres y
## trébol, repartidos de forma irregular con ruido. Se dibuja una sola vez;
## el viento lo anima el shader grass_sway (las puntas van marcadas en el alfa).

const SHADER = preload("res://shaders/grass_sway.gdshader")
const INK = Color(0.16, 0.11, 0.1)
const FLOWERS = [
	Color(0.97, 0.62, 0.72),  # nadeshiko (rosa)
	Color(0.58, 0.52, 0.86),  # kikyō (campanilla)
	Color(0.98, 0.97, 0.92),  # blanca
	Color(0.97, 0.84, 0.32),  # ominaeshi (amarilla)
]

@export var island_path: NodePath = ^"../Island"
@export_range(0.0, 2.0) var density: float = 1.0:
	set(v):
		density = v
		queue_redraw()

var _island: Island
var _dens: FastNoiseLite
var _flow: FastNoiseLite


func _ready() -> void:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	material = mat
	_island = get_node_or_null(island_path) as Island
	if _island and not _island.regenerated.is_connected(queue_redraw):
		_island.regenerated.connect(queue_redraw)
	queue_redraw()


func _flex(c: Color, f: float) -> Color:
	return Color(c.r, c.g, c.b, 1.0 - 0.02 * f)


func _draw() -> void:
	if _island == null or _island.land_cells.is_empty():
		return
	_dens = FastNoiseLite.new()
	_dens.seed = _island.seed_value * 7 + 3
	_dens.frequency = 0.17
	_flow = FastNoiseLite.new()
	_flow.seed = _island.seed_value * 5 + 1
	_flow.frequency = 0.32
	# orden de atrás hacia delante para que las matas se solapen bien
	var cells: Array[Vector2i] = _island.land_cells.duplicate()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x + a.y < b.x + b.y)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for cell: Vector2i in cells:
		var t: int = _island.tiles[cell]
		if t < Island.T.GRASS:
			continue
		rng.seed = hash(cell) ^ _island.seed_value
		var gx: float = float(cell.x)
		var gy: float = float(cell.y)
		var edge: bool = false
		for d: Vector2i in Island.DIRS:
			if not (_island.tiles.get(cell + d, Island.T.DEEP) >= Island.T.GRASS):
				edge = true
		# matas: zonas densas y claros despejados
		var dn: float = _dens.get_noise_2d(gx, gy) * 0.5 + 0.5
		var tufts: int = int(round(lerpf(0.0, 5.0, smoothstep(0.25, 0.85, dn)) * density))
		if edge:
			tufts += 1
		for i in tufts:
			var g: Vector2 = Vector2(gx + rng.randf_range(0.1, 0.9), gy + rng.randf_range(0.1, 0.9))
			_tuft(g, rng, dn)
		# susuki: juncos altos plateados en los bordes de la pradera
		if edge and rng.randf() < 0.28:
			_susuki(Vector2(gx + rng.randf_range(0.2, 0.8), gy + rng.randf_range(0.2, 0.8)), rng)
		# flores silvestres en grupos
		var fl: float = _flow.get_noise_2d(gx, gy)
		if fl > 0.18 and rng.randf() < 0.85:
			var kind: Color = FLOWERS[int(absf(_flow.get_noise_2d(gx * 0.3 + 50.0, gy * 0.3)) * 8.0) % FLOWERS.size()]
			for k in rng.randi_range(2, 5):
				_flower(Vector2(gx + rng.randf_range(0.1, 0.9), gy + rng.randf_range(0.1, 0.9)), kind, rng)
		# trébol en el musgo
		if t == Island.T.MOSS and rng.randf() < 0.5:
			_clover(Vector2(gx + rng.randf_range(0.2, 0.8), gy + rng.randf_range(0.2, 0.8)), rng)


func _base(g: Vector2) -> Vector2:
	return Iso.to_screen(g) - Vector2(0, Island.LAND_H)


## Brizna: triángulo curvado con la punta "flexible".
func _blade(root: Vector2, height: float, lean: float, width: float, col_root: Color, col_tip: Color) -> void:
	var dir: Vector2 = Vector2(sin(lean), -cos(lean))
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var tip: Vector2 = root + dir * height + perp * lean * height * 0.35
	var mid: Vector2 = root + dir * height * 0.55 + perp * lean * height * 0.12
	var pts: PackedVector2Array = PackedVector2Array([root - perp * width * 0.5, mid - perp * width * 0.3, tip, mid + perp * width * 0.3, root + perp * width * 0.5])
	var cols: PackedColorArray = PackedColorArray([
		_flex(col_root, 0.0), _flex(col_root.lerp(col_tip, 0.5), 0.45), _flex(col_tip, 1.0),
		_flex(col_root.lerp(col_tip, 0.5), 0.45), _flex(col_root, 0.0)])
	draw_polygon(pts, cols)


func _tuft(g: Vector2, rng: RandomNumberGenerator, dn: float) -> void:
	var root: Vector2 = _base(g)
	var base_col: Color = _island.grass_color(g)
	var dark: Color = base_col.darkened(0.35)
	var light: Color = base_col.lightened(0.18)
	var n: int = rng.randi_range(3, 6)
	var tall: float = lerpf(4.0, 8.5, dn) * rng.randf_range(0.8, 1.2)
	# sombra suave en la base
	draw_colored_polygon(_ellipse(root + Vector2(1, 0.5), 3.5, 1.4), Color(0.1, 0.15, 0.05, 0.18))
	for i in n:
		var lean: float = lerpf(-0.6, 0.6, (float(i) + rng.randf()) / float(n))
		var tip_col: Color = light if rng.randf() < 0.6 else base_col
		if rng.randf() < 0.15:
			tip_col = Color(0.2, 0.33, 0.2) # pincelada oscura de tinta
		_blade(root + Vector2(rng.randf_range(-2.0, 2.0), 0), tall * rng.randf_range(0.6, 1.0), lean, 1.6, dark, tip_col)


func _susuki(g: Vector2, rng: RandomNumberGenerator) -> void:
	var root: Vector2 = _base(g)
	draw_colored_polygon(_ellipse(root + Vector2(2, 0.5), 5.0, 2.0), Color(0.1, 0.15, 0.05, 0.2))
	var stalks: int = rng.randi_range(3, 5)
	for i in stalks:
		var lean: float = lerpf(-0.35, 0.45, float(i) / float(stalks)) + rng.randf_range(-0.1, 0.1)
		var h: float = rng.randf_range(13.0, 19.0)
		var r: Vector2 = root + Vector2(rng.randf_range(-2.5, 2.5), 0)
		_blade(r, h, lean, 1.3, Color(0.45, 0.52, 0.3), Color(0.72, 0.7, 0.5))
		# penacho plumoso
		var dir: Vector2 = Vector2(sin(lean), -cos(lean))
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var tip: Vector2 = r + dir * h + perp * lean * h * 0.35
		var plume: PackedVector2Array = PackedVector2Array([tip, tip + dir * 2.0 + perp * 2.2, tip + dir * 7.0 + perp * 1.0, tip + dir * 8.0, tip + dir * 3.0 - perp * 1.6])
		var pc: Color = Color(0.93, 0.88, 0.76)
		var pcs: PackedColorArray = PackedColorArray()
		for k in plume.size():
			pcs.append(_flex(pc if k > 0 else pc.darkened(0.1), 1.0))
		draw_polygon(plume, pcs)
	# hojas largas arqueadas en la base
	for side: float in [-1.0, 1.0]:
		_blade(root, 9.0, side * 0.9, 1.8, Color(0.33, 0.47, 0.27), Color(0.55, 0.62, 0.38))


func _flower(g: Vector2, col: Color, rng: RandomNumberGenerator) -> void:
	var root: Vector2 = _base(g)
	var h: float = rng.randf_range(4.0, 7.5)
	var lean: float = rng.randf_range(-0.3, 0.3)
	_blade(root, h, lean, 1.0, Color(0.3, 0.45, 0.25), Color(0.4, 0.58, 0.3))
	var dir: Vector2 = Vector2(sin(lean), -cos(lean))
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var c: Vector2 = root + dir * h + perp * lean * h * 0.35
	var petals: PackedVector2Array = PackedVector2Array()
	var pcs: PackedColorArray = PackedColorArray()
	for k in 10:
		var a: float = TAU * float(k) / 10.0
		var r: float = 2.4 if k % 2 == 0 else 1.1
		petals.append(c + Vector2(cos(a) * r, sin(a) * r * 0.8))
		pcs.append(_flex(col, 1.0))
	draw_polygon(petals, pcs)
	var center: PackedVector2Array = PackedVector2Array()
	var ccs: PackedColorArray = PackedColorArray()
	for k2 in 5:
		var a2: float = TAU * float(k2) / 5.0
		center.append(c + Vector2(cos(a2), sin(a2)) * 0.7)
		ccs.append(_flex(Color(0.95, 0.75, 0.25) if col != FLOWERS[3] else Color(0.75, 0.45, 0.15), 1.0))
	draw_polygon(center, ccs)


func _clover(g: Vector2, rng: RandomNumberGenerator) -> void:
	var c: Vector2 = _base(g)
	var col: Color = _island.grass_color(g).darkened(0.25)
	for k in rng.randi_range(2, 4):
		var o: Vector2 = Vector2(rng.randf_range(-5, 5), rng.randf_range(-2, 2))
		for leaf in 3:
			var a: float = TAU * float(leaf) / 3.0 - PI * 0.5
			draw_colored_polygon(_ellipse(c + o + Vector2(cos(a), sin(a) * 0.6) * 1.4, 1.3, 0.9), col)


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 10:
		var a: float = TAU * float(i) / 10.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
