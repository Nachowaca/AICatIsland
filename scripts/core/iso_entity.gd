@tool
class_name IsoEntity
extends Node2D
## Base para todo lo que vive sobre la isla. Se posiciona con grid_pos
## (coordenadas de rejilla) y ofrece utilidades de dibujo isométrico.

const LAND_H = 10.0
const INK = Color(0.16, 0.11, 0.1)

@export var grid_pos: Vector2 = Vector2(13, 13):
	set(v):
		grid_pos = v
		_update_position()

@export var elevated: bool = true:
	set(v):
		elevated = v
		_update_position()


func _enter_tree() -> void:
	_update_position()


## Si es true, la altura cambia suavemente (subir/bajar el talud de pasto).
var smooth_ground: bool = false
var _h_cur: float = -1.0


func _update_position() -> void:
	var h: float = 0.0
	if elevated:
		h = Island.instance.height_at(grid_pos) if is_instance_valid(Island.instance) else LAND_H
	if smooth_ground and _h_cur >= 0.0 and is_inside_tree() and not Engine.is_editor_hint():
		_h_cur = move_toward(_h_cur, h, 1.3)
	else:
		_h_cur = h
	position = Iso.to_screen(grid_pos) - Vector2(0.0, _h_cur)


## Punto de pantalla local para una coordenada de rejilla relativa y altura en px.
func gp(gx: float, gy: float, h: float = 0.0) -> Vector2:
	return Iso.to_screen(Vector2(gx, gy)) - Vector2(0.0, h)


func draw_iso_box(cx: float, cy: float, a: float, b: float, h0: float, h1: float,
		top: Color, left: Color, right: Color, outline: bool = true) -> void:
	iso_box_on(self, Vector2.ZERO, cx, cy, a, b, h0, h1, top, left, right, outline)


## Igual que draw_iso_box pero sobre otro CanvasItem (ci) desplazado `o`.
func iso_box_on(ci: CanvasItem, o: Vector2, cx: float, cy: float, a: float, b: float, h0: float, h1: float,
		top: Color, left: Color, right: Color, outline: bool = true) -> void:
	var n: Vector2 = gp(cx - a, cy - b, h1) + o
	var e: Vector2 = gp(cx + a, cy - b, h1) + o
	var s: Vector2 = gp(cx + a, cy + b, h1) + o
	var w: Vector2 = gp(cx - a, cy + b, h1) + o
	var s0: Vector2 = gp(cx + a, cy + b, h0) + o
	var w0: Vector2 = gp(cx - a, cy + b, h0) + o
	var e0: Vector2 = gp(cx + a, cy - b, h0) + o
	ci.draw_colored_polygon(PackedVector2Array([w0, s0, s, w]), left)
	ci.draw_colored_polygon(PackedVector2Array([s0, e0, e, s]), right)
	ci.draw_colored_polygon(PackedVector2Array([n, e, s, w]), top)
	if outline:
		var ink: Color = Color(INK, 0.8)
		ci.draw_polyline(PackedVector2Array([w, n, e, s, w, w0, s0, e0, e]), ink, 1.0)
		ci.draw_line(s, s0, ink, 1.0)


## Polígono a partir de puntos (x, y, altura) en rejilla relativa.
func iso_poly(pts: Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector3 in pts:
		out.append(gp(p.x, p.y, p.z))
	return out


func ellipse_points(c: Vector2, rx: float, ry: float, n: int = 20) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func fill_ellipse(c: Vector2, rx: float, ry: float, col: Color, outline_w: float = 0.0) -> void:
	var pts: PackedVector2Array = ellipse_points(c, rx, ry)
	draw_colored_polygon(pts, col)
	if outline_w > 0.0:
		pts.append(pts[0])
		draw_polyline(pts, Color(INK, 0.85), outline_w)


func draw_shadow(r: float, offset: Vector2 = Vector2.ZERO, alpha: float = 0.25) -> void:
	draw_colored_polygon(ellipse_points(offset, r, r * 0.5), Color(0.05, 0.05, 0.12, alpha))
