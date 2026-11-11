class_name WashiInfoPanels
extends CanvasLayer
## Paneles de información con estilo "washi": papel claro translúcido, tinta sumi,
## acentos bermellón e índigo, sello hanko y olas seigaiha dibujadas a mano (_draw).
## Prototipo aislado: no sustituye todavía al HUD original.

const INK: Color = Color(0.16, 0.11, 0.1)
const VERMILION: Color = Color(0.72, 0.18, 0.12)
const INDIGO: Color = Color(0.16, 0.24, 0.44)
const PAPER_DAY: Color = Color(0.96, 0.93, 0.85, 0.88)
const PAPER_NIGHT: Color = Color(0.86, 0.85, 0.9, 0.92)
## Pigmentos apagados por necesidad (ocre, índigo claro, ciruela, verde matcha, ámbar).
const NEED_COLORS: Dictionary = {
	"hunger": Color(0.74, 0.45, 0.22),
	"energy": Color(0.28, 0.4, 0.62),
	"fun": Color(0.64, 0.32, 0.44),
	"safety": Color(0.38, 0.52, 0.32),
	"comfort": Color(0.76, 0.6, 0.24),
}
const PANEL_W: float = 230.0
const MARGIN: float = 8.0
const UPDATE_INTERVAL_MS: int = 250
const CONTROLS_TEXT: String = "Rueda: zoom · Clic der.: mover · C: seguir · 1/2/3: velocidad · H: paneles · F11: pantalla completa"

var cat: Cat
var day_night: DayNight
var night: float = 0.0

var _root: Control
var _left: WashiPaper
var _right: WashiPaper
var _strip: WashiPaper
var _time_label: Label
var _need_bars: Dictionary = {}
var _action_label: Label
var _thought_label: Label
var _learn_label: Label
var _scores_label: Label
var _log_label: Label
var _sections: Array[Dictionary] = []
var _last_update_ms: int = -100000


## Fracción 0..1 de una barra; tolera máximos nulos/negativos y valores NaN.
static func bar_fraction(value: float, max_value: float = 100.0) -> float:
	if max_value <= 0.0 or is_nan(value) or is_nan(max_value):
		return 0.0
	return clampf(value / max_value, 0.0, 1.0)


## Color del papel según la noche (0 = día, 1 = noche): índigo cálido, sigue siendo claro.
static func paper_color(night_amount: float) -> Color:
	return PAPER_DAY.lerp(PAPER_NIGHT, clampf(night_amount, 0.0, 1.0))


func _ready() -> void:
	layer = 10
	_find_refs()
	_build()
	refresh()


func _find_refs() -> void:
	if not is_inside_tree():
		return
	if cat == null:
		cat = get_tree().get_first_node_in_group("cat") as Cat
	if day_night == null:
		day_night = get_tree().get_first_node_in_group("day_night") as DayNight


# --------------------------------------------------------------------------- construcción

func _label(text: String, size: int = 11, col: Color = INK) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _wrap_label(size: int = 10, col: Color = INK) -> Label:
	var l: Label = _label("", size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _vbox(sep: int = 3) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


## Sección con cabecera clicable (bermellón) que pliega/despliega su cuerpo.
func _section(parent: Container, title: String, open: bool) -> VBoxContainer:
	var body: VBoxContainer = _vbox(2)
	body.visible = open
	var btn: Button = Button.new()
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 11)
	for st: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(st, VERMILION)
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	empty.content_margin_top = 1.0
	empty.content_margin_bottom = 1.0
	for st: String in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		btn.add_theme_stylebox_override(st, empty)
	var entry: Dictionary = {"body": body, "button": btn, "title": title}
	_sections.append(entry)
	btn.pressed.connect(func() -> void:
		body.visible = not body.visible
		_sync_section_title(entry))
	parent.add_child(btn)
	parent.add_child(body)
	_sync_section_title(entry)
	return body


func _sync_section_title(entry: Dictionary) -> void:
	var body: VBoxContainer = entry["body"] as VBoxContainer
	var btn: Button = entry["button"] as Button
	btn.text = ("▾ " if body.visible else "▸ ") + String(entry["title"])


func _engraved_line() -> EngravedLine:
	var line: EngravedLine = EngravedLine.new()
	line.custom_minimum_size = Vector2(0, 6)
	return line


func _build() -> void:
	_root = Control.new()
	_root.name = "WashiRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# --- Panel izquierdo: estado del gato
	_left = WashiPaper.new()
	_left.name = "LeftPanel"
	_left.show_hanko = true
	_left.custom_minimum_size.x = PANEL_W
	_root.add_child(_left)
	var lv: VBoxContainer = _vbox(3)
	_left.add_child(lv)
	var title: Label = _label("猫 Gatito de la isla", 13, INK)
	lv.add_child(title)
	_time_label = _label("—", 10, INDIGO)
	lv.add_child(_time_label)
	lv.add_child(_engraved_line())
	for k: String in Cat.NEED_NAMES:
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nl: Label = _label(String(Cat.NEED_NAMES[k]), 10)
		nl.custom_minimum_size.x = 66
		row.add_child(nl)
		var bar: BrushBar = BrushBar.new()
		bar.pigment = NEED_COLORS.get(k, INDIGO) as Color
		bar.seed_offset = float(_need_bars.size()) * 1.7
		bar.custom_minimum_size = Vector2(0, 11)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		lv.add_child(row)
		_need_bars[k] = bar
	lv.add_child(_engraved_line())
	_action_label = _wrap_label(11, INK)
	lv.add_child(_action_label)
	_thought_label = _wrap_label(10, Color(INK, 0.72))
	lv.add_child(_thought_label)
	_left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, int(MARGIN))

	# --- Panel derecho: mente
	_right = WashiPaper.new()
	_right.name = "RightPanel"
	_right.custom_minimum_size.x = PANEL_W
	_root.add_child(_right)
	var rv: VBoxContainer = _vbox(2)
	_right.add_child(rv)
	var learn_box: VBoxContainer = _section(rv, "Aprendizaje", true)
	_learn_label = _wrap_label(10)
	learn_box.add_child(_learn_label)
	rv.add_child(_engraved_line())
	var scores_box: VBoxContainer = _section(rv, "Opciones que sopesa", true)
	_scores_label = _wrap_label(10)
	scores_box.add_child(_scores_label)
	rv.add_child(_engraved_line())
	var log_box: VBoxContainer = _section(rv, "Diario", true)
	_log_label = _wrap_label(9, Color(INK, 0.85))
	log_box.add_child(_log_label)
	_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, int(MARGIN))
	_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	# --- Franja inferior de controles
	_strip = WashiPaper.new()
	_strip.name = "ControlsStrip"
	_strip.compact = true
	_root.add_child(_strip)
	var help: Label = _label(CONTROLS_TEXT, 10, INK)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_strip.add_child(help)
	_strip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, int(MARGIN))
	_strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_strip.grow_vertical = Control.GROW_DIRECTION_BEGIN


# --------------------------------------------------------------------------- API pública

func panels_visible() -> bool:
	return _root != null and _root.visible


func toggle_panels() -> void:
	if _root != null:
		_root.visible = not _root.visible


## Pliega (open = false) o despliega todas las secciones del panel derecho.
func set_all_sections_open(open: bool) -> void:
	for entry: Dictionary in _sections:
		(entry["body"] as VBoxContainer).visible = open
		_sync_section_title(entry)


func any_section_open() -> bool:
	for entry: Dictionary in _sections:
		if (entry["body"] as VBoxContainer).visible:
			return true
	return false


func section_count() -> int:
	return _sections.size()


## 0 = día, 1 = noche: el papel vira a un índigo cálido sin perder contraste con la tinta.
func set_night_factor(f: float) -> void:
	var v: float = clampf(f, 0.0, 1.0)
	if is_equal_approx(v, night):
		return
	night = v
	var papers: Array[WashiPaper] = [_left, _right, _strip]
	for p: WashiPaper in papers:
		if p != null:
			p.night = night
			p.queue_redraw()
	if _time_label != null:
		_time_label.add_theme_color_override("font_color", INDIGO.lerp(Color(0.12, 0.16, 0.34), night))


# --------------------------------------------------------------------------- bucle

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_H:
		toggle_panels()


func _process(_delta: float) -> void:
	if day_night != null and is_instance_valid(day_night):
		set_night_factor(day_night.night_factor())
	var now: int = Time.get_ticks_msec()
	if now - _last_update_ms < UPDATE_INTERVAL_MS:
		return
	_last_update_ms = now
	refresh()


## Actualiza todos los textos y barras (se llama a ~4 Hz).
func refresh() -> void:
	if _time_label == null:
		return
	if cat == null or day_night == null:
		_find_refs()
	if cat != null and not is_instance_valid(cat):
		cat = null
	if day_night != null and not is_instance_valid(day_night):
		day_night = null

	if day_night != null:
		var sky: String = "Luna" if day_night.is_night() else "Sol"
		_time_label.text = "Día %d · %s · %s · %s" % [day_night.day, day_night.time_string(), day_night.phase_name(), sky]
	else:
		_time_label.text = "Sin ciclo de día"

	if cat == null:
		for k: String in _need_bars:
			(_need_bars[k] as BrushBar).set_fraction(0.0)
		_action_label.text = "▶ (no hay gato en la escena)"
		_thought_label.text = ""
		_learn_label.text = "—"
		_scores_label.text = "—"
		_log_label.text = "—"
		return

	for k: String in _need_bars:
		(_need_bars[k] as BrushBar).set_fraction(bar_fraction(float(cat.needs.get(k, 0.0))))
	_action_label.text = "▶ " + cat.action_label()
	_thought_label.text = "«%s»" % cat.last_thought if cat.last_thought != "" else ""

	if cat.experimental_mode and cat.free_brain != null:
		var brain: FreeCatBrain = cat.free_brain
		_learn_label.text = "Ensayos: %d · Recuerdos: %d\nModelos: %d · Lugares: %d\nPescados comidos: %d" % [
			brain.completed_trials, brain.memory.size(), brain.models.size(), brain.places.size(), int(cat.stats.get("fish_eaten", 0))]
	else:
		_learn_label.text = "Cerebro clásico activo.\nPescados comidos: %d" % int(cat.stats.get("fish_eaten", 0))

	var scores: Array = cat.action_scores()
	var lines: PackedStringArray = PackedStringArray()
	for i: int in mini(4, scores.size()):
		var entry: Array = scores[i] as Array
		var raw_name: String = String(entry[0])
		var shown: String = String(Cat.ACTION_NAMES.get(raw_name, raw_name))
		var mark: String = "● " if i == 0 else "○ "
		lines.append("%s%s  %.2f" % [mark, shown, float(entry[1])])
	_scores_label.text = "\n".join(lines) if not lines.is_empty() else "Aún no sopesa nada."

	var log_tail: Array[String] = cat.log_lines.slice(-4)
	_log_label.text = "\n".join(PackedStringArray(log_tail)) if not log_tail.is_empty() else "Página en blanco."


# =========================================================================== dibujo

## Papel washi: fondo translúcido, borde de tinta doble, motivo seigaiha y sello opcional.
class WashiPaper extends PanelContainer:
	var night: float = 0.0
	var show_hanko: bool = false
	var compact: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _ready() -> void:
		var sb: StyleBoxEmpty = StyleBoxEmpty.new()
		if compact:
			sb.content_margin_left = 12.0
			sb.content_margin_right = 12.0
			sb.content_margin_top = 4.0
			sb.content_margin_bottom = 4.0
		else:
			sb.content_margin_left = 12.0
			sb.content_margin_right = 12.0
			sb.content_margin_top = 9.0
			sb.content_margin_bottom = 20.0
		add_theme_stylebox_override("panel", sb)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var paper: Color = WashiInfoPanels.paper_color(night)
		draw_rect(r, paper)
		# Fibras del washi: trazos muy tenues y deterministas.
		var fiber: Color = Color(WashiInfoPanels.INK, 0.035)
		var n: int = int(size.x * size.y / 900.0)
		for i: int in n:
			var fx: float = fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0) * size.x
			var fy: float = fposmod(sin(float(i) * 78.233) * 12345.678, 1.0) * size.y
			var ang: float = float(i) * 2.399
			var seg_len: float = 3.0 + fposmod(float(i) * 0.618, 1.0) * 6.0
			draw_line(Vector2(fx, fy), Vector2(fx, fy) + Vector2(cos(ang), sin(ang)) * seg_len, fiber, 1.0)
		if not compact:
			_draw_seigaiha(paper)
		# Borde: tinta exterior y línea de grabado interior.
		var ink: Color = WashiInfoPanels.INK
		draw_rect(r.grow(-1.0), Color(ink, 0.85), false, 1.5)
		draw_rect(r.grow(-4.0), Color(ink, 0.22), false, 1.0)
		if not compact:
			# Pequeño acento bermellón en la esquina superior izquierda.
			var v: Color = WashiInfoPanels.VERMILION
			draw_line(Vector2(4, 4), Vector2(18, 4), v, 2.0)
			draw_line(Vector2(4, 4), Vector2(4, 18), v, 2.0)
		if show_hanko:
			_draw_hanko()

	func _draw_seigaiha(paper: Color) -> void:
		var band_h: float = 14.0
		var radius: float = 7.0
		var top: float = size.y - band_h
		var wave: Color = Color(WashiInfoPanels.INDIGO, 0.32 + 0.12 * night)
		var rows: int = 3
		for row: int in rows:
			var cy: float = top + radius + float(row) * radius * 0.5
			var offset: float = radius if row % 2 == 1 else 0.0
			var x: float = -radius + offset
			while x < size.x + radius:
				var c: Vector2 = Vector2(x, cy)
				draw_circle(c, radius, paper)
				for k: int in 3:
					var rr: float = radius * (1.0 - float(k) * 0.3)
					draw_arc(c, rr, PI, TAU, 12, wave, 1.0, true)
				x += radius * 2.0
		draw_line(Vector2(5, top), Vector2(size.x - 5, top), Color(WashiInfoPanels.INDIGO, 0.25), 1.0)

	func _draw_hanko() -> void:
		var s: float = 22.0
		var pos: Vector2 = Vector2(size.x - s - 9.0, 8.0)
		var red: Color = Color(WashiInfoPanels.VERMILION, 0.9)
		var box: Rect2 = Rect2(pos, Vector2(s, s))
		draw_rect(box, red)
		draw_rect(box.grow(-2.0), Color(WashiInfoPanels.paper_color(night), 0.75), false, 1.0)
		var font: Font = ThemeDB.fallback_font
		if font != null:
			var fs: int = 15
			var asc: float = font.get_ascent(fs)
			var desc: float = font.get_descent(fs)
			var baseline: float = pos.y + (s - (asc + desc)) * 0.5 + asc
			draw_string(font, Vector2(pos.x, baseline), "猫", HORIZONTAL_ALIGNMENT_CENTER, s, fs, Color(0.98, 0.95, 0.9))


## Línea de grabado: un trazo de tinta que se adelgaza en los extremos.
class EngravedLine extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y: float = size.y * 0.5
		var ink: Color = WashiInfoPanels.INK
		draw_line(Vector2(size.x * 0.06, y), Vector2(size.x * 0.94, y), Color(ink, 0.18), 1.0)
		draw_line(Vector2(size.x * 0.2, y), Vector2(size.x * 0.8, y), Color(ink, 0.3), 1.0)
		draw_circle(Vector2(size.x * 0.5, y), 1.6, Color(WashiInfoPanels.VERMILION, 0.7))


## Barra pincelada: pista de tinta tenue y trazo de pigmento con bordes irregulares.
class BrushBar extends Control:
	var pigment: Color = Color(0.3, 0.3, 0.5)
	var seed_offset: float = 0.0
	var fraction: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func set_fraction(f: float) -> void:
		var v: float = clampf(f, 0.0, 1.0)
		if absf(v - fraction) < 0.002:
			return
		fraction = v
		queue_redraw()

	func _wobble(t: float, k: float) -> float:
		return sin(t * 0.37 + seed_offset + k) * 0.6 + sin(t * 0.91 + seed_offset * 2.3 + k) * 0.4

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var mid: float = h * 0.5
		var ink: Color = WashiInfoPanels.INK
		# Pista: línea fina de tinta diluida.
		draw_line(Vector2(0, mid + 2.5), Vector2(w, mid + 2.5), Color(ink, 0.22), 1.0)
		draw_line(Vector2(w - 1.0, mid - 3.0), Vector2(w - 1.0, mid + 3.0), Color(ink, 0.3), 1.0)
		var fw: float = w * fraction
		if fw < 1.5:
			return
		var steps: int = maxi(4, int(fw / 4.0))
		var top: PackedVector2Array = PackedVector2Array()
		var bottom: PackedVector2Array = PackedVector2Array()
		for i: int in steps + 1:
			var t: float = float(i) / float(steps)
			var x: float = t * fw
			# Grosor: arranque redondo, cuerpo pleno, cola que se afina como un pincel.
			var thick: float = (h * 0.42) * (0.75 + 0.25 * sin(minf(t * 6.0, PI * 0.5))) * (1.0 - 0.55 * smoothstep(0.82, 1.0, t))
			top.append(Vector2(x, mid - thick + _wobble(x, 0.0) * 0.7))
			bottom.append(Vector2(x, mid + thick * 0.8 + _wobble(x, 3.1) * 0.7))
		var poly: PackedVector2Array = top.duplicate()
		bottom.reverse()
		poly.append_array(bottom)
		draw_colored_polygon(poly, Color(pigment, 0.88))
		# Vetas de pincel secas.
		var streak: Color = Color(pigment.darkened(0.35), 0.45)
		for j: int in 2:
			var yy: float = mid - 1.5 + float(j) * 2.5
			draw_line(Vector2(fw * 0.08, yy), Vector2(fw * (0.6 + 0.25 * float(j)), yy + _wobble(float(j) * 9.0, 1.0) * 0.4), streak, 0.8)
