@tool
class_name Discoverable
extends IsoEntity
## Cosas de la isla que el gato NO conoce de antemano.
## El mundo define cómo responde cada cosa a cada verbo (respond); el gato
## solo ve "algo" (perceived_kind) y aprende probando qué le pasa.

signal event(what: String, thing: Discoverable)

enum Kind { BURIED_SHELL, BURIED_BELL, CRAB_ROCK, MATATABI, ROOT_HOLLOW }

const VERBS = ["sniff", "dig", "paw", "bite", "lie"]
const VERB_NAMES = {"sniff": "olfatear", "dig": "escarbar", "paw": "dar zarpazos a", "bite": "morder", "lie": "tumbarse en"}
const KIND_NAMES = {
	"mound": "un montículo", "shell": "la concha", "bell": "el cascabel", "rock": "la roca",
	"crab": "el cangrejo", "plant": "la planta blanca", "hollow": "el hueco entre raíces",
}

@export var kind: Kind = Kind.BURIED_SHELL:
	set(v):
		kind = v
		queue_redraw()
@export var buried: bool = true:
	set(v):
		buried = v
		queue_redraw()

var crab_out: bool = false
var _progress: float = 0.0
var _crab_t: float = 0.0
var _crab_gone_t: float = 0.0
var _t: float = 0.0
var _fx: float = 0.0      # intensidad de efecto visual (notas, corazones, polvo)
var _fx_kind: String = ""
var _day_night: Node


func _ready() -> void:
	add_to_group("discoverable")
	if kind == Kind.CRAB_ROCK or kind == Kind.MATATABI or kind == Kind.ROOT_HOLLOW:
		buried = false
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	_t += delta
	_fx = move_toward(_fx, 0.0, delta * 0.8)
	if _day_night == null:
		_day_night = get_tree().get_first_node_in_group("day_night")
		if _day_night and _day_night.has_signal("new_day"):
			_day_night.new_day.connect(_on_new_day)
	if crab_out:
		_crab_t += delta
		if _crab_t > 9.0:
			crab_out = false
	elif _crab_gone_t > 0.0:
		_crab_gone_t -= delta
	queue_redraw()


## Lo que el gato percibe: no sabe qué hay enterrado, solo ve un montículo.
func perceived_kind() -> String:
	match kind:
		Kind.BURIED_SHELL:
			return "mound" if buried else "shell"
		Kind.BURIED_BELL:
			return "mound" if buried else "bell"
		Kind.CRAB_ROCK:
			return "crab" if crab_out else "rock"
		Kind.MATATABI:
			return "plant"
	return "hollow"


func interact_point() -> Vector2:
	if kind == Kind.ROOT_HOLLOW:
		return grid_pos + Vector2(0.1, 0.15)
	return grid_pos + Vector2(0.4, 0.35)


## Qué le pasa a quien hace `verb` durante `dt` segundos. Devuelve el ritmo
## de cambio de cada necesidad (por segundo) y, en "_once", cambios puntuales
## (un hallazgo, un pellizco). Son las "leyes del mundo": el gato no las lee.
func respond(verb: String, dt: float, night: bool) -> Dictionary:
	var r: Dictionary = {}
	var pk: String = perceived_kind()
	match pk:
		"mound":
			match verb:
				"dig":
					r = {"fun": 1.5}
					_progress += dt
					_fx_kind = "dust"
					_fx = 1.0
					if _progress > 2.5:
						_progress = 0.0
						buried = false
						r["_once"] = {"fun": 18.0} # alegría del hallazgo
						event.emit("revealed", self)
				"sniff":
					r = {"fun": 0.6}
				"paw":
					r = {"fun": 0.4}
				"bite":
					r = {"comfort": -1.0}
				"lie":
					r = {"comfort": 0.4}
		"shell":
			match verb:
				"paw":
					r = {"fun": 6.0, "energy": -0.5}
					_fx_kind = "spin"
					_fx = 1.0
				"sniff":
					r = {"fun": 1.0}
				"bite":
					r = {"comfort": -2.0, "fun": 0.5}
				"dig":
					r = {"fun": 0.5}
		"bell":
			match verb:
				"paw":
					r = {"fun": 9.0, "energy": -1.0}
					_fx_kind = "notes"
					_fx = 1.0
				"bite":
					r = {"fun": 2.5}
					_fx_kind = "notes"
					_fx = 0.6
				"sniff":
					r = {"fun": 0.3}
		"rock":
			match verb:
				"paw":
					r = {"fun": 0.8}
					if _crab_gone_t <= 0.0:
						_progress += dt
						if _progress > 1.5:
							_progress = 0.0
							crab_out = true
							_crab_t = 0.0
							r["_once"] = {"fun": 10.0, "safety": -4.0}
							event.emit("crab_out", self)
				"sniff":
					r = {"fun": 1.0}
				"lie":
					r = {"comfort": -1.0}
				"dig":
					r = {"fun": 0.5}
				"bite":
					r = {"comfort": -1.5}
		"crab":
			match verb:
				"paw":
					r = {"fun": 7.0, "energy": -1.5}
					_crab_t = maxf(0.0, _crab_t - dt * 0.5)
				"bite":
					r = {"hunger": 5.0, "comfort": -4.0, "safety": -1.0}
					_progress += dt
					if _progress > 2.5:
						_progress = 0.0
						crab_out = false
						_crab_gone_t = 80.0
						r["_once"] = {"hunger": 20.0}
						event.emit("crab_eaten", self)
					elif randf() < dt * 0.5:
						event.emit("pinch", self)
				"sniff":
					r = {"safety": -2.0, "fun": 1.0}
					if randf() < dt * 0.4:
						event.emit("pinch", self)
		"plant":
			match verb:
				"sniff":
					r = {"fun": 10.0, "comfort": 2.0, "energy": -2.0}
					_fx_kind = "hearts"
					_fx = 1.0
				"bite":
					r = {"fun": 6.0, "hunger": 0.5}
					_fx_kind = "hearts"
					_fx = 0.6
				"lie":
					r = {"comfort": 2.0, "fun": 2.0}
				"paw":
					r = {"fun": 2.0}
		"hollow":
			match verb:
				"lie":
					r = {"safety": 5.0 if night else 2.5, "comfort": 2.0, "energy": 2.0}
				"sniff":
					r = {"fun": 0.5}
				"dig":
					r = {"fun": 1.0, "comfort": -0.5}
					_fx_kind = "dust"
					_fx = 0.7
	return r


## Al cambiar de día la marea/el viento vuelven a esconder la concha y el cascabel.
func _on_new_day(_d: int) -> void:
	if (kind == Kind.BURIED_SHELL or kind == Kind.BURIED_BELL) and not buried and randf() < 0.6:
		var isl: Island = Island.instance
		if isl:
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.randomize()
			for i in 12:
				var p: Vector2 = grid_pos + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
				if isl.is_walkable(p) and isl.is_walkable(p + Vector2(0.5, 0.5)):
					grid_pos = p
					break
		buried = true


# ---------------------------------------------------------------- dibujo

func _draw() -> void:
	match kind:
		Kind.BURIED_SHELL, Kind.BURIED_BELL:
			if buried:
				_draw_mound()
			elif kind == Kind.BURIED_SHELL:
				_draw_shell()
			else:
				_draw_bell()
		Kind.CRAB_ROCK:
			_draw_rock()
		Kind.MATATABI:
			_draw_matatabi()
		Kind.ROOT_HOLLOW:
			_draw_hollow()
	_draw_fx()


func _draw_mound() -> void:
	var on_sand: bool = Island.instance != null and Island.instance.tile_at(grid_pos) == Island.T.SAND
	var col: Color = Color(0.86, 0.75, 0.55) if on_sand else Color(0.5, 0.38, 0.25)
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 13:
		var a: float = PI + PI * float(i) / 12.0
		pts.append(Vector2(cos(a) * 11.0, sin(a) * 5.0 - 1.0))
	pts.append(Vector2(11, 2))
	pts.append(Vector2(-11, 2))
	draw_colored_polygon(pts, col)
	draw_polyline(pts, Color(INK, 0.5), 1.0)
	draw_line(Vector2(-4, -3), Vector2(-1, -4), col.darkened(0.25), 1.0)
	draw_line(Vector2(2, -2), Vector2(5, -3), col.darkened(0.25), 1.0)
	# un destello leve de vez en cuando: "aquí hay algo"
	var tw: float = maxf(0.0, sin(_t * 1.3 + grid_pos.x))
	if tw > 0.93:
		var c: Vector2 = Vector2(3, -5)
		draw_line(c + Vector2(-3, 0), c + Vector2(3, 0), Color(1, 1, 0.85, 0.9), 1.0)
		draw_line(c + Vector2(0, -3), c + Vector2(0, 3), Color(1, 1, 0.85, 0.9), 1.0)


func _draw_shell() -> void:
	draw_shadow(7.0, Vector2(1, 1), 0.25)
	var spin: float = sin(_t * 12.0) * 0.3 * _fx
	draw_set_transform(Vector2(0, -3), spin, Vector2.ONE)
	var fan: PackedVector2Array = PackedVector2Array([Vector2(0, 3)])
	for i in 9:
		var a: float = PI + PI * float(i) / 8.0
		fan.append(Vector2(cos(a) * 7.0, sin(a) * 6.0))
	draw_colored_polygon(fan, Color(1.0, 0.88, 0.84))
	for i in 5:
		var a2: float = PI + PI * (float(i) + 0.5) / 5.0
		draw_line(Vector2(0, 3), Vector2(cos(a2) * 6.5, sin(a2) * 5.5), Color(0.92, 0.6, 0.6), 1.0)
	fan.append(fan[0])
	draw_polyline(fan, Color(INK, 0.8), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_bell() -> void:
	draw_shadow(6.0, Vector2(1, 1), 0.25)
	var jingle: float = sin(_t * 30.0) * 0.25 * _fx
	draw_set_transform(Vector2(0, -5), jingle, Vector2.ONE)
	draw_circle(Vector2.ZERO, 5.0, Color(0.92, 0.72, 0.22))
	draw_arc(Vector2.ZERO, 5.0, 0, TAU, 16, INK, 1.1)
	draw_line(Vector2(-4, 0.5), Vector2(4, 0.5), Color(0.55, 0.38, 0.1), 1.0)
	draw_circle(Vector2(0, 2.2), 1.0, INK)
	draw_line(Vector2(0, 2.2), Vector2(0, 4.5), INK, 1.0)
	draw_arc(Vector2(-1.5, -1.8), 1.8, PI, PI * 1.6, 5, Color(1, 1, 0.9, 0.9), 1.0)
	draw_line(Vector2(0, -5), Vector2(-3, -8), Color(0.8, 0.15, 0.15), 1.5)
	draw_line(Vector2(0, -5), Vector2(3, -8), Color(0.8, 0.15, 0.15), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_rock() -> void:
	draw_shadow(14.0, Vector2(2, 2), 0.25)
	var rock: PackedVector2Array = PackedVector2Array([
		Vector2(-13, 1), Vector2(-11, -7), Vector2(-4, -12), Vector2(5, -11), Vector2(12, -5), Vector2(13, 2), Vector2(0, 4)])
	draw_colored_polygon(rock, Color(0.5, 0.5, 0.48))
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -6), Vector2(-4, -11), Vector2(4, -10), Vector2(-2, -6)]), Color(0.63, 0.63, 0.6))
	draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(-6, -2), Vector2(2, 0), Vector2(0, 4)]), Color(0.3, 0.42, 0.28, 0.8))
	rock.append(rock[0])
	draw_polyline(rock, INK, 1.2)
	if crab_out:
		var x: float = 16.0 + sin(_crab_t * 5.0) * 5.0
		var c: Vector2 = Vector2(x, 2)
		for side: float in [-1.0, 1.0]:
			for k in 3:
				var base: Vector2 = c + Vector2(side * 3.0, float(k) - 1.0)
				draw_line(base, base + Vector2(side * 4.0, 2.0 + sin(_crab_t * 20.0 + float(k)) * 1.0), Color(0.75, 0.2, 0.12), 1.0)
		fill_ellipse(c + Vector2(0, -1), 5.0, 3.2, Color(0.88, 0.3, 0.18), 1.0)
		for side2: float in [-1.0, 1.0]:
			var claw: Vector2 = c + Vector2(side2 * 6.5, -4.0)
			draw_line(c + Vector2(side2 * 3.0, -2.0), claw, Color(0.75, 0.2, 0.12), 1.4)
			draw_circle(claw, 1.8, Color(0.88, 0.3, 0.18))
		draw_circle(c + Vector2(-1.5, -4.2), 0.9, INK)
		draw_circle(c + Vector2(1.5, -4.2), 0.9, INK)
	elif _crab_gone_t <= 0.0:
		# dos ojitos asoman a veces bajo la roca
		if fmod(_t, 7.0) < 0.8:
			draw_circle(Vector2(11, 1), 0.9, INK)
			draw_circle(Vector2(13, 1.5), 0.9, INK)


func _draw_matatabi() -> void:
	draw_shadow(13.0, Vector2(2, 2), 0.22)
	var sway: float = sin(_t * 1.4 + grid_pos.x) * 1.2
	for i in 7:
		var a: float = lerpf(-1.1, 1.1, float(i) / 6.0)
		var tip: Vector2 = Vector2(sin(a) * 12.0 + sway, -10.0 - cos(a) * 8.0)
		draw_line(Vector2(0, 0), tip, Color(0.3, 0.45, 0.22), 1.2)
		var leaf: Color = Color(0.36, 0.58, 0.3) if i % 2 == 0 else Color(0.93, 0.95, 0.88)
		var dir: Vector2 = tip.normalized()
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([tip - dir * 6.0, tip + perp * 2.6, tip + dir * 2.0, tip - perp * 2.6]), leaf)
		draw_polyline(PackedVector2Array([tip - dir * 6.0, tip + perp * 2.6, tip + dir * 2.0, tip - perp * 2.6, tip - dir * 6.0]), Color(INK, 0.5), 0.8)
	for f: Vector2 in [Vector2(-5, -9), Vector2(6, -12), Vector2(1, -15)]:
		draw_circle(f + Vector2(sway, 0), 1.4, Color(1, 1, 0.95))
		draw_circle(f + Vector2(sway, 0), 0.6, Color(0.95, 0.8, 0.3))


func _draw_hollow() -> void:
	var earth: Color = Color(0.42, 0.3, 0.2)
	var mound: PackedVector2Array = PackedVector2Array()
	for i in 15:
		var a: float = PI + PI * float(i) / 14.0
		mound.append(Vector2(cos(a) * 18.0, sin(a) * 11.0))
	mound.append(Vector2(18, 3))
	mound.append(Vector2(-18, 3))
	draw_colored_polygon(mound, earth)
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -2), Vector2(-8, -9), Vector2(4, -10), Vector2(14, -4), Vector2(6, -6), Vector2(-6, -5)]), Color(0.36, 0.52, 0.3))
	draw_polyline(mound, INK, 1.2)
	# boca oscura de la guarida
	var hole: PackedVector2Array = PackedVector2Array()
	for i in 11:
		var a2: float = PI + PI * float(i) / 10.0
		hole.append(Vector2(2, 3) + Vector2(cos(a2) * 8.0, sin(a2) * 7.0))
	draw_colored_polygon(hole, Color(0.1, 0.07, 0.06))
	# raíces
	for r: Array in [[Vector2(-16, 0), Vector2(-9, -6), Vector2(-4, -3)], [Vector2(15, 1), Vector2(10, -6), Vector2(5, -8)], [Vector2(-4, -10), Vector2(0, -6)]]:
		var line: PackedVector2Array = PackedVector2Array(r)
		draw_polyline(line, INK, 3.4)
		draw_polyline(line, Color(0.5, 0.35, 0.24), 2.0)


func _draw_fx() -> void:
	if _fx <= 0.01:
		return
	var font: Font = ThemeDB.fallback_font
	match _fx_kind:
		"notes":
			for i in 2:
				var k: float = fmod(_t * 0.8 + float(i) * 0.5, 1.0)
				draw_string(font, Vector2(6 + i * 6, -10 - k * 18), "♪", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.2, 0.5, _fx * (1.0 - k)))
		"hearts":
			for i in 3:
				var k2: float = fmod(_t * 0.6 + float(i) * 0.33, 1.0)
				draw_string(font, Vector2(-8 + i * 8, -16 - k2 * 22), "♥", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.4, 0.6, _fx * (1.0 - k2)))
		"dust":
			for i in 5:
				var k3: float = fmod(_t * 2.0 + float(i) * 0.2, 1.0)
				var dir: float = -1.0 if i % 2 == 0 else 1.0
				draw_circle(Vector2(dir * (4.0 + k3 * 10.0), -2.0 - sin(k3 * PI) * 8.0), 1.4, Color(0.6, 0.48, 0.32, _fx * (1.0 - k3)))
