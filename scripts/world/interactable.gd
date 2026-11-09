@tool
class_name Interactable
extends IsoEntity
## Objetos con los que el gato puede interactuar.
## SHELTER: santuario-casita (dormir, protegerse)  SCRATCH_POST: rascador
## TEMARI: pelota tradicional  LANTERN: chōchin de papel con vela  TORII: decorativo

enum Kind { SHELTER, SCRATCH_POST, TEMARI, LANTERN, TORII }

const CHOCHIN_RED = preload("res://assets/generated/chochin_red.png")
const CHOCHIN_CREAM = preload("res://assets/generated/chochin_cream.png")
const RED = Color(0.78, 0.16, 0.1)
const RED_DARK = Color(0.58, 0.1, 0.07)
const STONE = Color(0.66, 0.65, 0.6)
const STONE_L = Color(0.55, 0.54, 0.5)
const STONE_R = Color(0.45, 0.44, 0.41)
# Santuario (medidas en rejilla / píxeles de altura)
const SH_A = 1.3        # medio lado de la plataforma
const SH_W = 1.1        # medio lado de paredes y pilares
const SH_EAVE = 1.55    # medio lado del alero
const SH_FLOOR = 6.0
const SH_TOP = 36.0
const FRONT_SORT_Y = 24.0  # punto de orden Y de la parte delantera

@export var kind: Kind = Kind.SHELTER:
	set(v):
		kind = v
		_setup_light()
		_setup_front()
		queue_redraw()
@export var display_name: String = ""
@export var lantern_cream: bool = false:
	set(v):
		lantern_cream = v
		queue_redraw()

var _light: PointLight2D
var _wiggle: float = 0.0
var _roll: float = 0.0
var _t: float = 0.0
var _last_pos: Vector2
var _day_night: Node
var _front: Node2D
var _cat: Node2D


func _ready() -> void:
	add_to_group("interactable")
	_setup_light()
	_setup_front()
	_last_pos = grid_pos
	set_process(not Engine.is_editor_hint())


func _setup_front() -> void:
	if not is_inside_tree():
		return
	if kind == Kind.SHELTER and _front == null:
		y_sort_enabled = true
		_front = Node2D.new()
		_front.name = "Front"
		_front.position = Vector2(0, FRONT_SORT_Y)
		_front.draw.connect(_draw_shelter_front)
		add_child(_front)
	elif kind != Kind.SHELTER and _front != null:
		_front.queue_free()
		_front = null


## ¿Está el gato dentro del santuario (sobre la plataforma)?
func contains(g: Vector2) -> bool:
	var d: Vector2 = g - grid_pos
	return kind == Kind.SHELTER and absf(d.x) < SH_A and absf(d.y) < SH_A


func _process(delta: float) -> void:
	_t += delta
	if _front:
		if _cat == null:
			_cat = get_tree().get_first_node_in_group("cat") as Node2D
		var inside: bool = _cat != null and contains((_cat as IsoEntity).grid_pos)
		_front.modulate.a = move_toward(_front.modulate.a, 0.35 if inside else 1.0, delta * 2.5)
		_front.queue_redraw()
	_wiggle = move_toward(_wiggle, 0.0, delta * 1.5)
	if kind == Kind.TEMARI:
		_roll += (grid_pos - _last_pos).length() * 6.0
		_last_pos = grid_pos
	if _day_night == null:
		_day_night = get_tree().get_first_node_in_group("day_night")
	queue_redraw()


func label() -> String:
	return display_name if display_name != "" else String(name)


func interact_point() -> Vector2:
	match kind:
		Kind.SHELTER:
			return grid_pos + Vector2(0.15, 0.2)
		Kind.TEMARI:
			return grid_pos + Vector2(-0.45, 0.25)
		Kind.TORII:
			return grid_pos
		_:
			return grid_pos + Vector2(0.55, 0.55)


func wiggle() -> void:
	_wiggle = 1.0


## La pelota rueda en una dirección aleatoria dentro de la isla.
func nudge(island: Island, rng: RandomNumberGenerator) -> void:
	for i in 8:
		var dir: Vector2 = Vector2.RIGHT.rotated(rng.randf() * TAU)
		var dist: float = rng.randf_range(0.7, 1.4)
		var dest: Vector2 = grid_pos + dir * dist
		if island.is_walkable(dest) and island.is_walkable(dest + dir * 0.6):
			var tw: Tween = create_tween()
			tw.tween_property(self, "grid_pos", dest, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			return


func _night() -> float:
	if _day_night and _day_night.has_method("night_factor"):
		return _day_night.night_factor()
	return 0.0


func _setup_light() -> void:
	var wants: bool = kind == Kind.LANTERN or kind == Kind.SHELTER
	if wants and _light == null:
		_light = PointLight2D.new()
		var tex: GradientTexture2D = GradientTexture2D.new()
		tex.width = 256
		tex.height = 256
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		var grad: Gradient = Gradient.new()
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		tex.gradient = grad
		_light.texture = tex
		_light.color = Color(1.0, 0.62, 0.27)
		_light.energy = 0.0
		_light.texture_scale = 0.75 if kind == Kind.LANTERN else 0.85
		_light.position = Vector2(0, -27) if kind == Kind.LANTERN else gp(-0.78, -0.78, 14)
		_light.add_to_group("night_lights")
		add_child(_light)
	elif not wants and _light != null:
		_light.queue_free()
		_light = null


# ---------------------------------------------------------------- dibujo

func _draw() -> void:
	match kind:
		Kind.SHELTER:
			_draw_shelter()
		Kind.SCRATCH_POST:
			_draw_post()
		Kind.TEMARI:
			_draw_temari()
		Kind.LANTERN:
			_draw_lantern()
		Kind.TORII:
			_draw_torii()


## Parte trasera del santuario: plataforma, suelo de tatami, paredes del
## fondo, pergamino, lámpara y cojín. Se dibuja DETRÁS del gato.
func _draw_shelter() -> void:
	var A: float = SH_A
	var W: float = SH_W
	var F: float = SH_FLOOR
	var TOP: float = SH_TOP
	var nf: float = _night()
	draw_shadow(78.0, Vector2(10, 8), 0.25)
	draw_iso_box(0, 0, A, A, 0, F, STONE, STONE_L, STONE_R)
	# suelo de madera (engawa)
	var wood: Color = Color(0.6, 0.43, 0.29)
	draw_colored_polygon(iso_poly([Vector3(-A + 0.06, -A + 0.06, F), Vector3(A - 0.06, -A + 0.06, F), Vector3(A - 0.06, A - 0.06, F), Vector3(-A + 0.06, A - 0.06, F)]), wood)
	for i in range(1, 10):
		var y: float = lerpf(-A, A, float(i) / 10.0)
		draw_line(gp(-A + 0.06, y, F), gp(A - 0.06, y, F), wood.darkened(0.15), 1.0)
	# dos tatamis con su borde (heri)
	for mat: Array in [[-W + 0.08, -0.02], [0.02, W - 0.08]]:
		var x0: float = mat[0]
		var x1: float = mat[1]
		var poly: PackedVector2Array = iso_poly([Vector3(x0, -W + 0.08, F), Vector3(x1, -W + 0.08, F), Vector3(x1, W - 0.08, F), Vector3(x0, W - 0.08, F)])
		draw_colored_polygon(poly, Color(0.8, 0.78, 0.52))
		for k in range(1, 12):
			var yy: float = lerpf(-W + 0.08, W - 0.08, float(k) / 12.0)
			draw_line(gp(x0, yy, F), gp(x1, yy, F), Color(0.7, 0.68, 0.44, 0.6), 0.8)
		poly.append(poly[0])
		draw_polyline(poly, Color(0.22, 0.3, 0.2), 1.6)
	# paredes del fondo (se ven por dentro)
	var wall_l: PackedVector2Array = iso_poly([Vector3(-W, -W, F), Vector3(-W, W, F), Vector3(-W, W, TOP), Vector3(-W, -W, TOP)])
	var wall_r: PackedVector2Array = iso_poly([Vector3(-W, -W, F), Vector3(W, -W, F), Vector3(W, -W, TOP), Vector3(-W, -W, TOP)])
	draw_colored_polygon(wall_l, Color(0.95, 0.9, 0.79))
	draw_colored_polygon(wall_r, Color(0.86, 0.8, 0.68))
	var frame: Color = Color(0.4, 0.27, 0.18)
	for hh: float in [F + 0.5, 26.0, TOP]:
		draw_line(gp(-W, W, hh), gp(-W, -W, hh), frame, 2.0)
		draw_line(gp(-W, -W, hh), gp(W, -W, hh), frame, 2.0)
	# shōji en la pared derecha del fondo
	for k in range(1, 6):
		var xx: float = lerpf(-W, W, float(k) / 6.0)
		draw_line(gp(xx, -W, F + 1), gp(xx, -W, 26), frame, 1.0)
	for hh2: float in [12.0, 19.0]:
		draw_line(gp(-W, -W, hh2), gp(W, -W, hh2), Color(frame, 0.7), 1.0)
	# pergamino colgante (kakejiku) con un ensō
	var sc: PackedVector2Array = iso_poly([Vector3(-W + 0.01, -0.28, 11), Vector3(-W + 0.01, 0.28, 11), Vector3(-W + 0.01, 0.28, 31), Vector3(-W + 0.01, -0.28, 31)])
	draw_colored_polygon(sc, Color(0.32, 0.4, 0.55))
	var sp: PackedVector2Array = iso_poly([Vector3(-W + 0.01, -0.2, 13), Vector3(-W + 0.01, 0.2, 13), Vector3(-W + 0.01, 0.2, 28), Vector3(-W + 0.01, -0.2, 28)])
	draw_colored_polygon(sp, Color(0.97, 0.94, 0.86))
	draw_arc(gp(-W, 0, 20.5), 4.2, 0.5, TAU - 0.2, 18, INK, 1.6)
	# lámpara andon en la esquina
	var lamp: Color = Color(0.9, 0.85, 0.72).lerp(Color(1.0, 0.82, 0.45), nf)
	draw_iso_box(-0.78, -0.78, 0.14, 0.14, F, F + 13, lamp.lightened(0.1), lamp, lamp.darkened(0.12))
	draw_iso_box(-0.78, -0.78, 0.17, 0.17, F + 13, F + 15, frame, frame.darkened(0.1), frame.darkened(0.2))
	# pilar trasero
	draw_line(gp(-W, -W, F), gp(-W, -W, TOP), INK, 6.0)
	draw_line(gp(-W, -W, F), gp(-W, -W, TOP), RED, 4.0)
	# cojín zabuton donde le gusta dormir
	var cushion: Color = Color(0.56, 0.18, 0.32)
	draw_iso_box(0.15, 0.2, 0.42, 0.42, F, F + 3, cushion.lightened(0.15), cushion, cushion.darkened(0.2))
	for c: Vector2 in [Vector2(-0.27, -0.22), Vector2(0.57, -0.22), Vector2(0.57, 0.62), Vector2(-0.27, 0.62)]:
		draw_circle(gp(c.x, c.y, F + 3), 1.3, Color(0.95, 0.8, 0.3))


## Parte delantera: barandilla, pilares, viga, noren y tejado. Se dibuja
## DELANTE del gato (es un nodo hijo con su propio orden Y) y se vuelve
## translúcida cuando el gato está dentro.
func _draw_shelter_front() -> void:
	var ci: Node2D = _front
	var o: Vector2 = Vector2(0, -FRONT_SORT_Y)
	var W: float = SH_W
	var F: float = SH_FLOOR
	var TOP: float = SH_TOP
	var p: Callable = func(x: float, y: float, h: float) -> Vector2: return gp(x, y, h) + o
	# barandilla baja en el lado derecho
	var rail: Color = Color(0.55, 0.12, 0.08)
	for k in 6:
		var yy: float = lerpf(-W, W, float(k) / 5.0)
		ci.draw_line(p.call(W, yy, F), p.call(W, yy, F + 9), rail, 2.0)
	ci.draw_line(p.call(W, -W, F + 9), p.call(W, W, F + 9), INK, 3.5)
	ci.draw_line(p.call(W, -W, F + 9), p.call(W, W, F + 9), RED, 2.2)
	# pilares delanteros
	for c: Vector2 in [Vector2(W, -W), Vector2(-W, W), Vector2(W, W)]:
		ci.draw_line(p.call(c.x, c.y, F), p.call(c.x, c.y, TOP), INK, 6.0)
		ci.draw_line(p.call(c.x, c.y, F), p.call(c.x, c.y, TOP), RED, 4.0)
	# vigas superiores
	var beam: PackedVector2Array = PackedVector2Array([p.call(-W, W, TOP), p.call(W, W, TOP), p.call(W, -W, TOP)])
	ci.draw_polyline(beam, INK, 6.0)
	ci.draw_polyline(beam, RED, 4.0)
	# noren (cortina) en la entrada, se mece con la brisa
	var sway: float = sin(_t * 1.6) * 0.04
	for k in 3:
		var x0: float = lerpf(-0.8, 0.8, float(k) / 3.0) + 0.03
		var x1: float = lerpf(-0.8, 0.8, float(k + 1) / 3.0) - 0.03
		var panel: PackedVector2Array = PackedVector2Array([
			p.call(x0, W, TOP - 1), p.call(x1, W, TOP - 1),
			p.call(x1 + sway, W, TOP - 13), p.call(x0 + sway, W, TOP - 13)])
		ci.draw_colored_polygon(panel, Color(0.16, 0.24, 0.44))
		panel.append(panel[0])
		ci.draw_polyline(panel, Color(INK, 0.7), 1.0)
	ci.draw_arc(p.call(0.0 + sway, W, TOP - 7), 3.0, 0, TAU, 14, Color(0.95, 0.93, 0.88), 1.4)
	# tejado de cuatro aguas con tejas kawara
	var E: float = SH_EAVE
	var RB: float = TOP + 1.0
	var RH: float = TOP + 28.0
	var r1: Vector2 = p.call(-0.55, 0, RH)
	var r2: Vector2 = p.call(0.55, 0, RH)
	var nw: Vector2 = p.call(-E, -E, RB)
	var ne: Vector2 = p.call(E, -E, RB)
	var se: Vector2 = p.call(E, E, RB)
	var sw: Vector2 = p.call(-E, E, RB)
	var tile_dark: Color = Color(0.2, 0.22, 0.3)
	ci.draw_colored_polygon(PackedVector2Array([nw, ne, r2, r1]), tile_dark)
	ci.draw_colored_polygon(PackedVector2Array([nw, sw, r1]), Color(0.25, 0.27, 0.36))
	ci.draw_colored_polygon(PackedVector2Array([ne, se, r2]), Color(0.23, 0.25, 0.34))
	ci.draw_colored_polygon(PackedVector2Array([sw, se, r2, r1]), Color(0.31, 0.34, 0.45))
	for k in range(1, 14):
		var f: float = float(k) / 14.0
		ci.draw_line(sw.lerp(se, f), r1.lerp(r2, f), Color(tile_dark, 0.85), 1.0)
	for k in range(1, 6):
		var f2: float = float(k) / 6.0
		ci.draw_line(se.lerp(ne, f2), r2, Color(tile_dark, 0.6), 1.0)
	# canto blanco del alero y contornos
	ci.draw_polyline(PackedVector2Array([sw, se, ne]), Color(0.88, 0.85, 0.78), 3.0)
	ci.draw_polyline(PackedVector2Array([sw, se, ne]), INK, 1.2)
	ci.draw_polyline(PackedVector2Array([sw, r1, r2, se]), INK, 1.4)
	ci.draw_line(r2, ne, INK, 1.2)
	ci.draw_line(r1, nw, Color(INK, 0.6), 1.0)
	# cumbrera con onigawara
	ci.draw_line(r1, r2, INK, 4.0)
	ci.draw_polyline(PackedVector2Array([r1, r1 + Vector2(-4, -2), r1 + Vector2(-6, -7)]), INK, 2.5)
	ci.draw_polyline(PackedVector2Array([r2, r2 + Vector2(4, -2), r2 + Vector2(6, -7)]), INK, 2.5)
	# esquinas del alero levantadas
	ci.draw_polyline(PackedVector2Array([sw, sw + Vector2(-4, -2), sw + Vector2(-6, -6)]), INK, 2.0)
	ci.draw_polyline(PackedVector2Array([se, se + Vector2(0, -3), se + Vector2(1, -7)]), INK, 2.0)
	ci.draw_polyline(PackedVector2Array([ne, ne + Vector2(4, -2), ne + Vector2(6, -6)]), INK, 2.0)


func _draw_post() -> void:
	draw_shadow(16.0, Vector2(3, 2), 0.25)
	draw_iso_box(0, 0, 0.36, 0.36, 0, 4, Color(0.75, 0.6, 0.42), Color(0.65, 0.5, 0.34), Color(0.55, 0.42, 0.28))
	var lean: float = sin(_t * 30.0) * 1.5 * _wiggle
	var top: Vector2 = Vector2(lean, -36)
	draw_line(Vector2(0, -4), top, INK, 9.0)
	draw_line(Vector2(0, -4), top, Color(0.86, 0.76, 0.52), 7.0)
	for i in 10:
		var p: Vector2 = Vector2(0, -4).lerp(top, float(i) / 10.0)
		draw_line(p + Vector2(-3.5, 0), p + Vector2(3.5, -1), Color(0.65, 0.53, 0.33), 1.0)
	draw_set_transform(Vector2(lean, 0), 0.0, Vector2.ONE)
	draw_iso_box(0, 0, 0.3, 0.3, 36, 39, Color(0.75, 0.6, 0.42), Color(0.65, 0.5, 0.34), Color(0.55, 0.42, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# pompón colgante
	var anchor: Vector2 = top + Vector2(8, -1)
	var swing: float = sin(_t * 3.0) * 0.25 + sin(_t * 14.0) * 0.6 * _wiggle
	var bob: Vector2 = anchor + Vector2(sin(swing) * 12.0, cos(swing) * 12.0)
	draw_line(anchor, bob, INK, 1.0)
	draw_circle(bob, 3.2, Color(0.85, 0.2, 0.25))
	draw_arc(bob, 3.2, 0, TAU, 12, INK, 1.0)


func _draw_temari() -> void:
	draw_shadow(9.0, Vector2(1, 1), 0.3)
	var c: Vector2 = Vector2(0, -7)
	draw_circle(c, 7.0, Color(0.97, 0.93, 0.86))
	var cols: Array = [Color(0.85, 0.15, 0.18), Color(0.2, 0.35, 0.7), Color(0.95, 0.72, 0.2)]
	for i in 6:
		var ang: float = _roll + float(i) * PI / 6.0
		var dir: Vector2 = Vector2.RIGHT.rotated(ang)
		draw_line(c - dir * 6.5, c + dir * 6.5, cols[i % 3], 1.6)
	draw_circle(c, 2.3, Color(0.85, 0.15, 0.18))
	draw_arc(c, 7.0, 0, TAU, 20, INK, 1.2)
	draw_arc(c + Vector2(-2, -2), 4.0, PI * 1.1, PI * 1.5, 6, Color(1, 1, 1, 0.7), 1.2)


func _draw_lantern() -> void:
	# Chōchin pequeño suspendido de un soporte de madera, no una luminaria eléctrica.
	draw_shadow(10.0, Vector2(-3, 2), 0.22)
	var wood: Color = Color(0.35, 0.23, 0.15)
	draw_iso_box(-0.35, 0, 0.16, 0.16, 0, 3, wood.lightened(0.12), wood, wood.darkened(0.2))
	var base: Vector2 = gp(-0.35, 0, 3)
	var top: Vector2 = base + Vector2(0, -49)
	draw_line(base, top, INK, 4.0)
	draw_line(base, top, wood, 2.5)
	draw_polyline(PackedVector2Array([top + Vector2(0, 9), top, Vector2(0, top.y)]), INK, 3.0)
	draw_polyline(PackedVector2Array([top + Vector2(0, 9), top, Vector2(0, top.y)]), wood, 1.5)
	var sway: float = sin(_t * 1.2 + grid_pos.x) * 0.035
	var texture: Texture2D = CHOCHIN_CREAM if lantern_cream else CHOCHIN_RED
	draw_set_transform(Vector2(0, top.y), sway)
	draw_texture_rect(texture, Rect2(-21, 0, 42, 42), false)
	draw_set_transform(Vector2.ZERO)



func _draw_torii() -> void:
	# reflejo en el agua
	draw_line(gp(0, -0.75), gp(0, -0.75) + Vector2(0, 18), Color(RED, 0.25), 5.0)
	draw_line(gp(0, 0.75), gp(0, 0.75) + Vector2(0, 18), Color(RED, 0.25), 5.0)
	for py: float in [-0.75, 0.75]:
		draw_iso_box(0, py, 0.12, 0.12, -1, 3, Color(0.2, 0.18, 0.18), Color(0.15, 0.13, 0.13), Color(0.1, 0.1, 0.1), false)
		draw_line(gp(0, py, 2), gp(0, py, 52), INK, 7.0)
		draw_line(gp(0, py, 2), gp(0, py, 52), RED, 5.0)
	# nuki (travesaño)
	draw_line(gp(0, -1.0, 40), gp(0, 1.0, 40), INK, 6.0)
	draw_line(gp(0, -1.0, 40), gp(0, 1.0, 40), RED, 4.0)
	# gakuzuka
	draw_line(gp(0, 0, 40), gp(0, 0, 52), RED_DARK, 4.0)
	# kasagi (dintel superior curvado)
	draw_line(gp(0, -1.25, 52), gp(0, 1.25, 52), INK, 7.0)
	draw_line(gp(0, -1.25, 52), gp(0, 1.25, 52), RED, 5.0)
	draw_polyline(PackedVector2Array([gp(0, -1.45, 60), gp(0, -1.15, 56), gp(0, 1.15, 56), gp(0, 1.45, 60)]), INK, 4.0)
