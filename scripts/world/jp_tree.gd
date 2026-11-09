@tool
class_name JpTree
extends IsoEntity
## Árbol japonés procedural: sakura, pino niwaki, momiji o bambú.
## Da sombra (grupo "shade") y el gato puede dormir debajo.

enum Kind { SAKURA, PINE, MOMIJI, BAMBOO }

@export var kind: Kind = Kind.SAKURA:
	set(v):
		kind = v
		queue_redraw()
@export var shade_radius: float = 1.6
@export var tree_scale: float = 1.0:
	set(v):
		tree_scale = v
		queue_redraw()

var _t: float = 0.0
var _phase: float = 0.0
var _petals: Array = [] # [Vector2 pos, Vector2 vel, float life]


func _ready() -> void:
	add_to_group("shade")
	_phase = fmod(grid_pos.x * 1.7 + grid_pos.y * 3.1, TAU)
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	_t += delta
	if kind == Kind.SAKURA or kind == Kind.MOMIJI:
		if randf() < delta * 1.2:
			_petals.append([Vector2(randf_range(-24, 24), randf_range(-60, -40)) * tree_scale, Vector2(randf_range(4, 12), randf_range(6, 12)), 0.0])
		for p: Array in _petals:
			p[2] += delta
			p[0] += (p[1] + Vector2(sin(_t * 2.0 + p[2] * 3.0) * 8.0, 0.0)) * delta
		_petals = _petals.filter(func(p: Array) -> bool: return p[0].y < 6.0 and p[2] < 8.0)
	queue_redraw()


func _seeded_rng() -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = int(grid_pos.x * 1000.0 + grid_pos.y * 37.0) + int(kind) * 7
	return r


func _draw() -> void:
	var sway: float = sin(_t * 0.9 + _phase) * 1.5
	draw_shadow(28.0 * tree_scale, Vector2(6, 2), 0.22)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(tree_scale, tree_scale))
	match kind:
		Kind.SAKURA:
			_draw_blossom_tree(sway, [Color(0.84, 0.47, 0.6), Color(0.96, 0.68, 0.78), Color(1.0, 0.86, 0.9)], Color(0.8, 0.3, 0.45))
		Kind.MOMIJI:
			_draw_blossom_tree(sway, [Color(0.58, 0.12, 0.1), Color(0.84, 0.27, 0.14), Color(0.98, 0.56, 0.22)], Color(1.0, 0.8, 0.35))
		Kind.PINE:
			_draw_pine(sway)
		Kind.BAMBOO:
			_draw_bamboo(sway)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var petal_col: Color = Color(1.0, 0.8, 0.86) if kind == Kind.SAKURA else Color(0.92, 0.4, 0.2)
	for p: Array in _petals:
		var pos: Vector2 = p[0]
		draw_colored_polygon(ellipse_points(pos, 2.0, 1.2, 6), petal_col)


const BARK = Color(0.33, 0.22, 0.17)
const BARK_LIGHT = Color(0.5, 0.36, 0.27)


## Rama que se afina: ancho w0 en la base, w1 en la punta. Primero tinta, luego corteza.
func _branch(pts: PackedVector2Array, w0: float, w1: float, ink_pass: bool) -> void:
	var n: int = pts.size()
	for i in n - 1:
		var t: float = float(i) / float(maxi(1, n - 2))
		var w: float = lerpf(w0, w1, t)
		if ink_pass:
			draw_line(pts[i], pts[i + 1], INK, w + 2.4)
			draw_circle(pts[i + 1], (w + 2.4) * 0.5, INK)
		else:
			draw_line(pts[i], pts[i + 1], BARK, w)
			draw_circle(pts[i + 1], w * 0.5, BARK)
			draw_line(pts[i] + Vector2(-w * 0.25, 0), pts[i + 1] + Vector2(-w * 0.25, 0), BARK_LIGHT, maxf(1.0, w * 0.25))


func _branches(list: Array) -> void:
	for pass_ink: bool in [true, false]:
		for b: Array in list:
			_branch(b[0], b[1], b[2], pass_ink)


## Silueta de nube festoneada (estilo grabado): lóbulos redondeados hacia fuera.
func _cloud(c: Vector2, rx: float, ry: float, lobes: int, phase: float, grow: float = 0.0, flat_bottom: float = 0.75) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = lobes * 6
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var bump: float = absf(sin(a * float(lobes) * 0.5 + phase))
		var k: float = 0.9 + 0.16 * bump
		var y_scale: float = flat_bottom if sin(a) > 0.0 else 1.0
		pts.append(c + Vector2(cos(a) * (rx * k + grow), sin(a) * (ry * k * y_scale + grow)))
	return pts


## Dibuja un grupo de copas como una sola masa: silueta de tinta común,
## base oscura, tono medio desplazado hacia arriba y luz arriba-izquierda.
func _canopy(clumps: Array, cols: Array, flat_bottom: float) -> void:
	for cl: Array in clumps:
		draw_colored_polygon(_cloud(cl[0], cl[1], cl[2], cl[3], cl[4], 1.6, flat_bottom), INK)
	for cl: Array in clumps:
		draw_colored_polygon(_cloud(cl[0], cl[1], cl[2], cl[3], cl[4], 0.0, flat_bottom), cols[0])
	for cl: Array in clumps:
		var c: Vector2 = cl[0]
		draw_colored_polygon(_cloud(c + Vector2(-1.0, -cl[2] * 0.22), cl[1] * 0.84, cl[2] * 0.7, cl[3], cl[4] + 0.6, 0.0, 1.0), cols[1])
	for cl: Array in clumps:
		var c2: Vector2 = cl[0]
		draw_colored_polygon(_cloud(c2 + Vector2(-cl[1] * 0.22, -cl[2] * 0.45), cl[1] * 0.42, cl[2] * 0.3, maxi(3, cl[3] - 2), cl[4] + 1.3, 0.0, 1.0), cols[2])


func _draw_blossom_tree(sway: float, cols: Array, accent: Color) -> void:
	var r: RandomNumberGenerator = _seeded_rng()
	var s: float = sway
	_branches([
		[PackedVector2Array([Vector2(2, 0), Vector2(-1, -10), Vector2(-4, -20), Vector2(-1, -30), Vector2(3 + s * 0.5, -40)]), 7.0, 4.0],
		[PackedVector2Array([Vector2(-4, -20), Vector2(-12, -27), Vector2(-22 + s * 0.7, -34)]), 3.6, 1.6],
		[PackedVector2Array([Vector2(-1, -29), Vector2(9, -35), Vector2(21 + s * 0.7, -40)]), 3.4, 1.6],
		[PackedVector2Array([Vector2(1, -36), Vector2(-5, -46), Vector2(-6 + s, -54)]), 2.6, 1.2],
	])
	var o: Vector2 = Vector2(s, 0)
	var clumps: Array = [
		[Vector2(-24, -38) + o * 0.7, 13.0, 9.0, 7, r.randf() * TAU],
		[Vector2(22, -43) + o * 0.7, 14.0, 9.5, 7, r.randf() * TAU],
		[Vector2(-3, -44) + o * 0.8, 17.0, 11.0, 9, r.randf() * TAU],
		[Vector2(-12, -56) + o, 12.0, 8.0, 7, r.randf() * TAU],
		[Vector2(10, -57) + o, 13.0, 8.5, 7, r.randf() * TAU],
		[Vector2(-1, -66) + o, 9.0, 6.0, 6, r.randf() * TAU],
	]
	_canopy(clumps, cols, 0.7)
	# flores/hojas sueltas: pequeños trazos en vez de puntos redondos
	for i in 16:
		var cl: Array = clumps[r.randi() % clumps.size()]
		var c: Vector2 = cl[0]
		var p: Vector2 = c + Vector2(r.randf_range(-cl[1], cl[1]) * 0.75, r.randf_range(-cl[2], cl[2]) * 0.6)
		var col: Color = accent if i % 3 == 0 else Color(1, 1, 1, 0.9)
		draw_line(p + Vector2(-1.4, 0), p + Vector2(1.4, 0), col, 1.0)
		draw_line(p + Vector2(0, -1.4), p + Vector2(0, 1.4), col, 1.0)
	# ramitas que asoman bajo la copa
	draw_line(Vector2(-18, -33) + o * 0.7, Vector2(-26, -30) + o * 0.7, INK, 1.2)
	draw_line(Vector2(17, -38) + o * 0.7, Vector2(25, -36) + o * 0.7, INK, 1.2)


func _draw_pine(sway: float) -> void:
	var r: RandomNumberGenerator = _seeded_rng()
	var s: float = sway
	_branches([
		[PackedVector2Array([Vector2(0, 0), Vector2(5, -12), Vector2(-3, -24), Vector2(-5, -32), Vector2(2, -44), Vector2(s, -58)]), 7.0, 3.0],
		[PackedVector2Array([Vector2(-4, -27), Vector2(-14, -29), Vector2(-24 + s * 0.6, -33)]), 3.4, 1.6],
		[PackedVector2Array([Vector2(1, -41), Vector2(12, -44), Vector2(23 + s * 0.7, -47)]), 3.0, 1.4],
		[PackedVector2Array([Vector2(-2, -50), Vector2(-10, -54)]), 2.2, 1.2],
	])
	var cols: Array = [Color(0.12, 0.27, 0.2), Color(0.22, 0.42, 0.28), Color(0.4, 0.6, 0.36)]
	# almohadillas niwaki: nubes planas y anchas, separadas en pisos
	var pads: Array = [
		[Vector2(-23, -36) + Vector2(s * 0.6, 0), 15.0, 7.5, 8, r.randf() * TAU],
		[Vector2(23, -50) + Vector2(s * 0.7, 0), 14.0, 7.0, 8, r.randf() * TAU],
		[Vector2(-11, -57) + Vector2(s * 0.8, 0), 11.0, 6.0, 7, r.randf() * TAU],
		[Vector2(s, -66), 13.0, 7.5, 8, r.randf() * TAU],
	]
	for pad: Array in pads:
		_canopy([pad], cols, 0.55)
		# abanicos de agujas (motivo clásico de los grabados de pinos)
		var c: Vector2 = pad[0]
		var w: float = pad[1]
		for k in 3:
			var x: float = lerpf(-w * 0.45, w * 0.45, float(k) / 2.0)
			var base: Vector2 = c + Vector2(x, pad[2] * 0.25)
			for j in 5:
				var a: float = lerpf(PI * 1.15, PI * 1.85, float(j) / 4.0)
				draw_line(base, base + Vector2(cos(a), sin(a)) * 3.2, Color(0.1, 0.24, 0.16, 0.75), 0.8)


func _draw_bamboo(sway: float) -> void:
	var r: RandomNumberGenerator = _seeded_rng()
	for i in 6:
		var base: Vector2 = Vector2(r.randf_range(-14, 14), r.randf_range(-4, 4))
		var height: float = r.randf_range(55, 80)
		var top: Vector2 = base + Vector2(sway * (height / 40.0), -height)
		draw_line(base, top, INK, 5.0)
		draw_line(base, top, Color(0.45, 0.66, 0.33), 3.4)
		var seg: int = int(height / 12.0)
		for k in seg:
			var p: Vector2 = base.lerp(top, float(k + 1) / float(seg + 1))
			draw_line(p + Vector2(-2, 0), p + Vector2(2, 0), Color(0.25, 0.4, 0.2), 1.4)
			if float(k) > float(seg) * 0.5:
				var side: float = 1.0 if (k + i) % 2 == 0 else -1.0
				var leaf: PackedVector2Array = PackedVector2Array([p, p + Vector2(side * 10, -3), p + Vector2(side * 14, 1), p + Vector2(side * 5, 2)])
				draw_colored_polygon(leaf, Color(0.32, 0.55, 0.28))
