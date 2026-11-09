class_name Hud
extends CanvasLayer
## Panel de observación: necesidades, acción actual, personalidad y diario.

const INK = Color(0.17, 0.11, 0.1)
const PAPER = Color(0.97, 0.93, 0.84, 0.93)
const NEED_COLORS = {
	"hunger": Color(0.9, 0.55, 0.25), "energy": Color(0.35, 0.55, 0.85), "fun": Color(0.85, 0.4, 0.6),
	"safety": Color(0.45, 0.68, 0.4), "comfort": Color(0.92, 0.75, 0.25),
}
const TRAIT_COLOR = Color(0.7, 0.2, 0.15)

var cat: Cat
var day_night: DayNight
var _time_label: Label
var _action_label: Label
var _thought_label: Label
var _need_bars: Dictionary = {}
var _trait_bars: Dictionary = {}
var _learn_label: Label
var _log_label: Label
var _speed_label: Label
var _scores_label: Label
var _panels: Array[Control] = []
var _disc_label: Label

const ACCENT = Color(0.62, 0.16, 0.1)
const LEFT_W = 190.0
const RIGHT_W = 215.0


func _ready() -> void:
	cat = get_tree().get_first_node_in_group("cat") as Cat
	day_night = get_tree().get_first_node_in_group("day_night") as DayNight
	_build()


func _style(bg: Color, border: Color, bw: int = 2) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(7)
	return sb


func _label(text: String, size: int = 13, col: Color = INK) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _bar(col: Color) -> ProgressBar:
	var pb: ProgressBar = ProgressBar.new()
	pb.custom_minimum_size = Vector2(0, 7)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.show_percentage = false
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg: StyleBoxFlat = _style(Color(0, 0, 0, 0.1), Color(INK, 0.6), 1)
	bg.set_content_margin_all(0)
	var fill: StyleBoxFlat = _style(col, Color(0, 0, 0, 0), 0)
	fill.set_content_margin_all(0)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fill)
	return pb


func _row(parent: Container, name_text: String, bar: ProgressBar) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	var l: Label = _label(name_text, 10)
	l.custom_minimum_size.x = 62
	h.add_child(l)
	h.add_child(bar)
	parent.add_child(h)


func _panel() -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(PAPER, Color(0.62, 0.16, 0.1)))
	return p


## Sección con cabecera clicable que pliega/despliega su contenido.
func _section(parent: Container, title: String, open: bool) -> VBoxContainer:
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	body.visible = open
	var btn: Button = Button.new()
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 10)
	for st: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(st, ACCENT)
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for st: String in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(st, empty)
	var set_text: Callable = func() -> void: btn.text = ("▾ " if body.visible else "▸ ") + title
	set_text.call()
	btn.pressed.connect(func() -> void:
		body.visible = not body.visible
		set_text.call())
	parent.add_child(btn)
	parent.add_child(body)
	return body


func _small_text(size: int = 10, col: Color = INK) -> Label:
	var l: Label = _label("", size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _build() -> void:
	# --- Panel izquierdo: estado
	var left: PanelContainer = _panel()
	left.position = Vector2(8, 8)
	left.custom_minimum_size.x = LEFT_W
	add_child(left)
	_panels.append(left)
	var lv: VBoxContainer = VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	left.add_child(lv)
	lv.add_child(_label("猫 Gatito de la isla", 12, ACCENT))
	_time_label = _label("", 10)
	lv.add_child(_time_label)
	var needs_box: VBoxContainer = _section(lv, "Necesidades", true)
	for k: String in Cat.NEED_NAMES:
		var b: ProgressBar = _bar(NEED_COLORS[k])
		_need_bars[k] = b
		_row(needs_box, Cat.NEED_NAMES[k], b)
	_action_label = _small_text(11)
	lv.add_child(_action_label)
	_thought_label = _small_text(10, Color(INK, 0.7))
	lv.add_child(_thought_label)
	var ia_box: VBoxContainer = _section(lv, "Opciones que sopesa (IA)", true)
	_scores_label = _label("", 9)
	ia_box.add_child(_scores_label)

	# --- Panel derecho: mente
	var right: PanelContainer = _panel()
	right.custom_minimum_size.x = RIGHT_W
	add_child(right)
	_panels.append(right)
	var rv: VBoxContainer = VBoxContainer.new()
	rv.add_theme_constant_override("separation", 2)
	right.add_child(rv)
	var mind_box: VBoxContainer = _section(rv, "Rasgos clásicos (inactivos)" if cat.experimental_mode else "Personalidad (evoluciona sola)", not cat.experimental_mode)
	for k: String in Cat.TRAIT_NAMES:
		var b2: ProgressBar = _bar(TRAIT_COLOR)
		b2.max_value = 1.0
		b2.step = 0.001
		_trait_bars[k] = b2
		_row(mind_box, Cat.TRAIT_NAMES[k], b2)
	var disc_box: VBoxContainer = _section(rv, "Descubrimientos (solo)", true)
	_disc_label = _small_text(9)
	disc_box.add_child(_disc_label)
	var learn_box: VBoxContainer = _section(rv, "Experimento libre" if cat.experimental_mode else "Aprendizaje", cat.experimental_mode)
	_learn_label = _small_text(9)
	learn_box.add_child(_learn_label)
	var log_box: VBoxContainer = _section(rv, "Diario", false)
	_log_label = _small_text(9)
	log_box.add_child(_log_label)
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	# --- Ayuda inferior
	var help: Label = _label("Clic orilla: pescado · Rueda: zoom · Clic der.: mover · C: seguir · 1/2/3: velocidad · H: paneles · F: pantalla completa · R: borrar memoria", 10, Color(1, 1, 1, 0.85))
	help.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	help.add_theme_constant_override("shadow_offset_x", 1)
	help.add_theme_constant_override("shadow_offset_y", 1)
	add_child(help)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 8)
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_speed_label = _label("", 10, Color(1, 1, 1, 0.85))
	_speed_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	add_child(_speed_label)
	_speed_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	_speed_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_speed_label.grow_vertical = Control.GROW_DIRECTION_BEGIN


## Resume lo que el gato aprendió probando: qué cosa+verbo sube o baja qué necesidad.
func _discoveries_text() -> String:
	if cat.experimental_mode and cat.free_brain != null:
		return "Aprende por objeto, verbo, zona y contexto.\n%d experiencias distintas · %d lugares recordados.\nEl detalle queda en el registro local." % [cat.free_brain.memory.size(), cat.free_brain.places.size()]
	if cat.knowledge.is_empty():
		return "Aún no ha probado nada. Todo es misterio."
	var rows: Array = []
	for key: String in cat.knowledge:
		var eff: Dictionary = cat.knowledge[key].eff
		var best_n: String = ""
		var best_v: float = 0.0
		var total: float = 0.0
		for n: String in eff:
			total += float(eff[n])
			if absf(float(eff[n])) > absf(best_v):
				best_v = float(eff[n])
				best_n = n
		rows.append([key, total, best_n, best_v])
	rows.sort_custom(func(x: Array, y: Array) -> bool: return x[1] > y[1])
	var lines: PackedStringArray = PackedStringArray()
	for i in mini(6, rows.size()):
		var parts: PackedStringArray = (rows[i][0] as String).split(":")
		var what: String = "%s %s" % [Discoverable.VERB_NAMES[parts[1]], Discoverable.KIND_NAMES.get(parts[0], "?")]
		var icon: String = "♥" if rows[i][1] > 2.0 else ("✗" if rows[i][1] < -0.5 else "·")
		var eff_txt: String = ""
		if absf(float(rows[i][3])) > 0.3:
			eff_txt = " (%s%s)" % ["+" if rows[i][3] > 0.0 else "−", Cat.NEED_NAMES[rows[i][2]]]
		lines.append("%s %s%s" % [icon, what, eff_txt])
	var known_kinds: Dictionary = {}
	for key2: String in cat.knowledge:
		known_kinds[key2.get_slice(":", 0)] = true
	lines.append("Probó %d cosas+acciones · conoce %d tipos" % [cat.knowledge.size(), known_kinds.size()])
	return "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_H:
		for p: Control in _panels:
			p.visible = not p.visible


func _process(_delta: float) -> void:
	if cat == null:
		return
	if day_night:
		var sky: String = "Luna · velas encendidas" if day_night.is_night() else "Sol"
		_time_label.text = "Día %d · %s · %s\n%s" % [day_night.day, day_night.time_string(), day_night.phase_name(), sky]
	for k: String in _need_bars:
		(_need_bars[k] as ProgressBar).value = float(cat.needs[k])
	for k: String in _trait_bars:
		(_trait_bars[k] as ProgressBar).value = float(cat.traits[k])
	_action_label.text = "▶ " + cat.action_label()
	_disc_label.text = _discoveries_text()
	_thought_label.text = "«%s»" % cat.last_thought if cat.last_thought != "" else ""

	var scores: Array = cat.action_scores()
	var st: String = ""
	for i in mini(4, scores.size()):
		var mark: String = "▶ " if scores[i][0] == cat.action else "   "
		st += "%s%s  %.2f\n" % [mark, Cat.ACTION_NAMES.get(scores[i][0], scores[i][0]), scores[i][1]]
	_scores_label.text = st.strip_edges(false, true)

	var items: Array = []
	for a: String in cat.learned:
		items.append([a, float(cat.learned[a])])
	items.sort_custom(func(x: Array, y: Array) -> bool: return x[1] > y[1])
	var txt: String = "Le sirve más:\n"
	for i in mini(3, items.size()):
		txt += "  %s  %.2f\n" % [Cat.ACTION_NAMES[items[i][0]], items[i][1]]
	txt += "Le sirve menos: %s  %.2f\n" % [Cat.ACTION_NAMES[items[-1][0]], items[-1][1]]
	var fav: String = "—"
	var fav_v: float = -1.0
	for o: String in cat.affinity:
		if float(cat.affinity[o]) > fav_v:
			fav_v = float(cat.affinity[o])
			fav = o
	txt += "Lugar favorito: %s\n" % fav
	txt += "Pescados %d · Siestas %d · Juegos %d\nLugares de pesca %d · Decisiones %d" % [
		int(cat.stats.fish_eaten), int(cat.stats.naps), int(cat.stats.plays), cat.fish_memory.size(), int(cat.stats.decisions)]
	if cat.experimental_mode and cat.free_brain != null:
		var brain: FreeCatBrain = cat.free_brain
		txt = "EXPERIMENTO LIBRE\nSemilla: %d\nEnsayos: %d · Recuerdos: %d\nCuriosidad: %.2f · Azar: %.2f\nSin soluciones predefinidas.\nR reinicia esta memoria." % [brain.actual_seed, brain.completed_trials, brain.memory.size(), brain.curiosity, brain.random_choice]
	_learn_label.text = txt
	_log_label.text = "\n".join(cat.log_lines.slice(-4))
	_speed_label.text = "Velocidad x%d" % int(Engine.time_scale)
