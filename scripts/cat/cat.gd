@tool
class_name Cat
extends IsoEntity
## Gatito autónomo.
## Cerebro: IA de utilidad (necesidades -> puntuación por acción) + aprendizaje
## por refuerzo simple (cada acción y cada objeto tienen un valor esperado que
## se ajusta con la experiencia) + memoria espacial (dónde aparece el pescado,
## qué zonas ya conoce) + rasgos de personalidad que derivan con el tiempo.
## El cerebro se guarda en user://gatito_brain.json para que evolucione entre sesiones.

const SAVE_PATH = "user://gatito_brain.json"
const ACTIONS = ["eat", "search_food", "sleep", "play_post", "play_ball", "shade_rest", "explore", "watch_sea", "seek_light", "groom", "interact"]
const PRIMARY = {
	"eat": ["hunger"], "search_food": ["hunger"], "sleep": ["energy"], "play_post": ["fun"],
	"play_ball": ["fun"], "shade_rest": ["comfort", "energy"], "explore": ["fun"],
	"watch_sea": ["fun", "safety"], "seek_light": ["safety"], "groom": ["comfort"], "interact": [],
}
const ACTION_NAMES = {
	"": "—", "eat": "Comer pescado", "search_food": "Buscar comida", "sleep": "Dormir",
	"play_post": "Usar el rascador", "play_ball": "Jugar con la temari", "shade_rest": "Descansar a la sombra",
	"explore": "Explorar", "watch_sea": "Contemplar el mar", "seek_light": "Buscar la luz del farol",
	"groom": "Acicalarse", "interact": "Investigar algo",
}
## Frases de la voz del gato. Se eligen según ánimo, evento y recuerdos.
const SAY = {
	"hunger": ["Miau… tengo hambre", "Huele a pescado… ¿o lo imagino?", "Mi pancita ruge", "¡Miaaau! ¿Comida?"],
	"energy": ["*bostezo*", "Ojitos pesados…", "Una siestecita…", "Mrrr… sueño"],
	"fun": ["Qué aburrido…", "¿Hay algo nuevo por aquí?", "Mrrp. Quiero jugar", "Nada que hacer…"],
	"safety": ["Qué oscuro está…", "¿Qué fue ese ruido?", "Mejor me escondo", "Brrr… no me gusta la noche"],
	"comfort": ["Uf, qué calor", "La arena quema", "Necesito sombra", "Me pica todo"],
	"happy": ["Prrr… prrr…", "Nya~", "Qué buen día", "Me gusta esta isla", "Mrrrp ♪", "La brisa huele bien"],
	"new": ["¿Qué es eso?", "Hmm… ¿y si…?", "Nunca probé esto", "A ver qué pasa…"],
	"love": ["¡Me encanta!", "¡Nyaaa~! ♥", "¡Otra vez, otra vez!", "¡Esto es lo mejor!"],
	"meh": ["Bah…", "No pasó nada", "Hmm, aburrido", "Eso no sirve"],
	"bad": ["¡Ay!", "¡Puaj!", "Nunca más…", "¡Ffff!"],
	"found": ["¡Había algo enterrado!", "¡Mira lo que encontré!", "¡Un tesoro!"],
	"pinch": ["¡Ay! ¡Me pellizcó!", "¡Fffft! ¡Pinzas!", "¡Suelta mi bigote!"],
	"crab": ["¡¿Un bicho?!", "¡Algo se mueve!", "¡Ahí, ahí!"],
	"inside": ["Aquí estoy a salvo", "Mi cojín…", "Qué calentito"],
}
const NEED_NAMES = {"hunger": "Saciedad", "energy": "Energía", "fun": "Diversión", "safety": "Seguridad", "comfort": "Confort"}
const TRAIT_NAMES = {"curiosity": "Curiosidad", "playfulness": "Juguetón", "laziness": "Pereza", "bravery": "Valentía"}

enum Phase { MOVING, DOING }

@export var walk_speed: float = 1.4
@export var persist_brain: bool = true
@export var experimental_mode: bool = true
var free_brain: FreeCatBrain


@export var needs: Dictionary = {"hunger": 75.0, "energy": 85.0, "fun": 65.0, "safety": 90.0, "comfort": 80.0}
var traits: Dictionary = {"curiosity": 0.5, "playfulness": 0.5, "laziness": 0.5, "bravery": 0.5}
var learned: Dictionary = {}
var affinity: Dictionary = {}
var fish_memory: Array = []
var stats: Dictionary = {"fish_eaten": 0, "naps": 0, "plays": 0, "days": 0, "decisions": 0}
var log_lines: Array[String] = []
## Lo que ha descubierto por sí mismo: "tipo:verbo" -> {n: veces, eff: {necesidad: ritmo}}
var knowledge: Dictionary = {}
## Nombres de cosas cuya ubicación recuerda (puede volver aunque no las vea).
var known_spots: Array = []

var action: String = ""
var thought: String = ""
var last_thought: String = ""
var phase: Phase = Phase.DOING
var pose: String = "sit"
var facing: float = 1.0

var _thought_time: float = 0.0
var _act_time: float = 0.0
var _act_duration: float = 2.0
var _needs_start: Dictionary = {}
var _target: Node2D = null
var _target_point: Vector2 = Vector2.ZERO
var _path: Array[Vector2] = []
var _look_point: Vector2 = Vector2.INF
var _anim_t: float = 0.0
var _stuck_t: float = 0.0
var _reeval_t: float = 0.0
var _save_t: float = 0.0
var _special_t: float = 0.0
var _visits: Dictionary = {}
var _last_cell: Vector2i = Vector2i(-999, -999)
var _island: Island
var _day_night: DayNight
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _int_verb: String = ""
var _int_key: String = ""
var _int_acc: Dictionary = {}
var _chat_t: float = 12.0
var _lift: float = 0.0


func _ready() -> void:
	add_to_group("cat")
	smooth_ground = true
	_build_sprite()
	if Engine.is_editor_hint():
		return
	_rng.randomize()
	_island = get_tree().get_first_node_in_group("island") as Island
	_day_night = get_tree().get_first_node_in_group("day_night") as DayNight
	_reset_learned()
	if experimental_mode:
		free_brain = get_node_or_null("FreeBrain") as FreeCatBrain
		if free_brain == null:
			free_brain = FreeCatBrain.new()
			free_brain.name = "FreeBrain"
			add_child(free_brain)
		free_brain.setup(self)
		return
	if persist_brain:
		_load_brain()
	if _day_night:
		_day_night.new_day.connect(_on_new_day)
	for n: Node in get_tree().get_nodes_in_group("discoverable"):
		(n as Discoverable).event.connect(_on_world_event)
	if int(stats.decisions) == 0:
		_log("Despierta por primera vez en la isla. Todo es nuevo.")
	else:
		_log("Vuelve a la isla recordando %d decisiones." % int(stats.decisions))
	_decide()


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		_save_brain()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_anim_t += delta
	_thought_time -= delta
	_update_needs(delta)
	_mark_visit()
	if experimental_mode and free_brain != null:
		free_brain.tick(delta)
		var free_floor: float = Interactable.SH_FLOOR if _in_shelter() else 0.0
		_lift = move_toward(_lift, free_floor, delta * 30.0)
		_update_position()
		_apply_pose(delta)
		queue_redraw()
		return
	if phase == Phase.MOVING:
		_move(delta)
	else:
		_perform(delta)
	_reeval_t += delta
	if _reeval_t > 1.5:
		_reeval_t = 0.0
		_maybe_interrupt()
	_save_t += delta
	if _save_t > 20.0:
		_save_t = 0.0
		_save_brain()
	_chat_t -= delta
	if _chat_t <= 0.0:
		_chat_t = _rng.randf_range(16.0, 32.0)
		if not (action == "sleep" and phase == Phase.DOING) and _thought_time <= 0.0:
			_say(_idle_line())
	# sube al suelo del santuario al entrar
	var floor_h: float = Interactable.SH_FLOOR if _in_shelter() else 0.0
	_lift = move_toward(_lift, floor_h, delta * 30.0)
	_update_position() # suaviza subir/bajar el talud de pasto
	_apply_pose(delta)
	queue_redraw()


# ================================================================ NECESIDADES

func _update_needs(delta: float) -> void:
	var sleeping: bool = (free_brain != null and free_brain.sleeping) if experimental_mode else (action == "sleep" and phase == Phase.DOING)
	var walking: bool = phase == Phase.MOVING
	var satiety_decay: float = 0.7
	if experimental_mode and free_brain != null:
		satiety_decay = free_brain.satiety_decay_per_second()
	needs.hunger -= satiety_decay * delta * (0.5 if sleeping else 1.0)
	if not sleeping:
		var energy_decay: float = (0.45 + (0.25 if walking else 0.0))
		if experimental_mode and free_brain != null:
			energy_decay = free_brain.energy_decay_per_second()
		needs.energy -= energy_decay * delta
	needs.fun -= (0.15 if sleeping else 0.75 + float(traits.playfulness) * 0.5) * delta
	var night: bool = _day_night != null and _day_night.is_night()
	if night:
		if _in_shelter() or _near_light():
			needs.safety += 1.5 * delta
		else:
			needs.safety -= (1.7 - float(traits.bravery)) * delta
	else:
		needs.safety += 1.0 * delta
	var heat: float = _day_night.heat() if _day_night else 0.0
	if heat > 0.3 and not _in_shade() and not _in_shelter():
		needs.comfort -= 2.2 * heat * delta
	else:
		needs.comfort += 1.0 * delta
	_clamp_needs()


func _clamp_needs() -> void:
	for k: String in needs:
		needs[k] = clampf(needs[k], 0.0, 100.0)


func _urg(n: String) -> float:
	return pow(1.0 - float(needs[n]) / 100.0, 1.6)


# ================================================================ PERCEPCIÓN

func _in_shade() -> bool:
	for t: Node in get_tree().get_nodes_in_group("shade"):
		var tree: JpTree = t as JpTree
		if tree and grid_pos.distance_to(tree.grid_pos) < tree.shade_radius:
			return true
	return false


func _in_shelter() -> bool:
	for s: Interactable in _interactables(Interactable.Kind.SHELTER):
		if s.contains(grid_pos):
			return true
	return false


# ---------------------------------------------------------------- descubrimiento

func _things() -> Array[Discoverable]:
	var out: Array[Discoverable] = []
	for n: Node in get_tree().get_nodes_in_group("discoverable"):
		out.append(n as Discoverable)
	return out


## ¿Lo ve? Las cosas enterradas se notan solo de cerca; las que ya
## encontró las recuerda aunque estén lejos.
func _perceives(th: Discoverable) -> bool:
	if String(th.name) in known_spots and th.perceived_kind() != "mound":
		return true
	var radius: float = 3.0 + float(traits.curiosity) * 5.0
	if th.perceived_kind() == "mound":
		radius *= 0.75
	return grid_pos.distance_to(th.grid_pos) <= radius


func _touched(kind_name: String) -> bool:
	for key: String in knowledge:
		if key.begins_with(kind_name + ":"):
			return true
	return false


## Valor esperado de un (tipo, verbo) según lo aprendido y las necesidades actuales.
func _known_value(key: String) -> float:
	var k: Dictionary = knowledge[key]
	var eff: Dictionary = k.eff
	var v: float = 0.0
	for n: String in eff:
		v += float(eff[n]) * (_urg(n) + 0.08) / 5.0
	return v + 0.12 / sqrt(float(k.n))


## Mejor cosa+verbo para probar ahora: [cosa, verbo, puntuación] o [].
func _best_interaction() -> Array:
	var best: Array = []
	var best_s: float = -INF
	var night: bool = _day_night != null and _day_night.is_night()
	for th: Discoverable in _things():
		if not _perceives(th):
			continue
		var pk: String = th.perceived_kind()
		var dist: float = grid_pos.distance_to(th.grid_pos)
		for verb: String in Discoverable.VERBS:
			var key: String = pk + ":" + verb
			var s: float
			if knowledge.has(key):
				s = _known_value(key)
			else:
				# curiosidad: lo nunca probado atrae, más si está aburrido,
				# y aún más si es una cosa que jamás ha tocado
				s = (0.35 + float(traits.curiosity) * 0.5) * (0.6 + _urg("fun"))
				if not _touched(pk):
					s += 0.15
				if night:
					s *= 0.4 + float(traits.bravery) * 0.6
			s -= dist * 0.025
			if s > best_s:
				best_s = s
				best = [th, verb, s]
	return best


func action_label() -> String:
	if experimental_mode and free_brain != null:
		return "Ensayo: " + free_brain.label
	if action == "interact" and _int_verb != "" and is_instance_valid(_target):
		var v: String = Discoverable.VERB_NAMES[_int_verb]
		return "%s%s %s" % [v.left(1).to_upper(), v.substr(1), Discoverable.KIND_NAMES.get(_int_key.get_slice(":", 0), "algo")]
	return str(ACTION_NAMES.get(action, action))


# ---------------------------------------------------------------- voz

func _say(text: String) -> void:
	_think(text)


func _pick(pool: String) -> String:
	var arr: Array = SAY[pool]
	return arr[_rng.randi() % arr.size()]


func _idle_line() -> String:
	var low: String = ""
	var low_v: float = 35.0
	for n: String in needs:
		if float(needs[n]) < low_v:
			low_v = float(needs[n])
			low = n
	if low != "":
		return _pick(low)
	if _in_shelter() and _rng.randf() < 0.5:
		return _pick("inside")
	# recuerda algo que le gustó
	if not knowledge.is_empty() and _rng.randf() < 0.45:
		var best_key: String = ""
		var best_fun: float = 2.0
		for key: String in knowledge:
			var f: float = float((knowledge[key].eff as Dictionary).get("fun", 0.0))
			if f > best_fun:
				best_fun = f
				best_key = key
		if best_key != "":
			var parts: PackedStringArray = best_key.split(":")
			return "Me acuerdo de %s… ♪" % Discoverable.KIND_NAMES.get(parts[0], "aquello")
	return _pick("happy")


func _on_world_event(what: String, th: Discoverable) -> void:
	match what:
		"revealed":
			var name_txt: String = Discoverable.KIND_NAMES.get(th.perceived_kind(), "algo")
			_say(_pick("found"))
			_log("¡Escarbando descubrió %s enterrado!" % name_txt)
			if not (String(th.name) in known_spots):
				known_spots.append(String(th.name))
		"crab_out":
			_say(_pick("crab"))
			if not knowledge.has("crab:paw") and not knowledge.has("crab:bite"):
				_log("Tocando la roca hizo salir un cangrejo.")
		"pinch":
			_say(_pick("pinch"))
		"crab_eaten":
			_say("¡Cangrejo crujiente!")
			_log("Cazó un cangrejo. Descubre otra forma de comer.")


func _near_light() -> bool:
	for s: Interactable in _interactables(Interactable.Kind.LANTERN):
		if grid_pos.distance_to(s.grid_pos) < 2.5:
			return true
	return false


func _interactables(kind: int) -> Array[Interactable]:
	var out: Array[Interactable] = []
	for n: Node in get_tree().get_nodes_in_group("interactable"):
		var it: Interactable = n as Interactable
		if it and it.kind == kind:
			out.append(it)
	return out


func _trees() -> Array[JpTree]:
	var out: Array[JpTree] = []
	for n: Node in get_tree().get_nodes_in_group("shade"):
		if n is JpTree:
			out.append(n as JpTree)
	return out


func _visible_fish() -> Fish:
	var best: Fish = null
	var bd: float = INF
	var vision: float = 7.0 + float(traits.curiosity) * 5.0
	for n: Node in get_tree().get_nodes_in_group("fish"):
		var f: Fish = n as Fish
		if f == null or f.is_queued_for_deletion():
			continue
		if f.claimed and f != _target:
			continue
		var d: float = grid_pos.distance_to(f.grid_pos)
		if d < vision and d < bd:
			bd = d
			best = f
	return best


func _aff(node: Node) -> float:
	if node == null:
		return 1.0
	return float(affinity.get(String(node.name), 1.0))


# ================================================================ DECISIÓN

func _score(a: String) -> float:
	var u: float = 0.0
	var night: bool = _day_night != null and _day_night.is_night()
	var heat: float = _day_night.heat() if _day_night else 0.0
	match a:
		"eat":
			if _visible_fish() == null:
				return -1.0
			u = _urg("hunger") * 1.7
		"search_food":
			if _visible_fish() != null:
				return -1.0
			u = _urg("hunger") * 1.2 * (0.6 + float(traits.curiosity) * 0.6)
		"sleep":
			u = _urg("energy") * 1.3 * (0.7 + float(traits.laziness) * 0.6)
			if night:
				u += 0.2 + _urg("safety") * 0.4
		"play_post":
			var posts: Array[Interactable] = _interactables(Interactable.Kind.SCRATCH_POST)
			if posts.is_empty():
				return -1.0
			u = _urg("fun") * (0.6 + float(traits.playfulness) * 0.8) * _aff(posts[0])
		"play_ball":
			var balls: Array[Interactable] = _interactables(Interactable.Kind.TEMARI)
			if balls.is_empty() or needs.energy < 15.0:
				return -1.0
			u = _urg("fun") * (0.65 + float(traits.playfulness) * 0.9) * _aff(balls[0])
		"shade_rest":
			if _trees().is_empty():
				return -1.0
			u = _urg("comfort") * 1.4 * (0.4 + heat) + _urg("energy") * 0.25
		"explore":
			u = 0.12 + float(traits.curiosity) * 0.25 + _urg("fun") * 0.3
			if night:
				u *= float(traits.bravery)
		"watch_sea":
			u = 0.1 + float(traits.curiosity) * 0.12 + _urg("fun") * 0.2
			if _day_night and _day_night.phase_name() in ["Atardecer", "Amanecer"]:
				u += 0.2
		"seek_light":
			if not night or _interactables(Interactable.Kind.LANTERN).is_empty():
				return -1.0
			u = _urg("safety") * 1.4
		"groom":
			u = 0.08 + float(traits.laziness) * 0.12 + _urg("comfort") * 0.2
		"interact":
			# sin multiplicadores a mano: todo sale de lo que descubrió
			if action == "interact" and phase == Phase.DOING and _int_key != "":
				return (_known_value(_int_key) if knowledge.has(_int_key) else 0.5) + 0.1
			var bi: Array = _best_interaction()
			return -1.0 if bi.is_empty() else float(bi[2])
	u *= float(learned.get(a, 1.0))
	if a == action:
		u += 0.1
	return u


## Puntuación actual de cada acción (sin ruido), ordenada de mayor a menor.
## Útil para ver "en qué está pensando" y para las pruebas.
func action_scores() -> Array:
	var out: Array = []
	if experimental_mode and free_brain != null:
		for option: Dictionary in free_brain.rankings.slice(0, 4):
			var verb_name: String = Discoverable.VERB_NAMES.get(option.verb, "acicalarse")
			var place_name: String = "suelo" if option.path == "" else String(option.path).get_file()
			out.append([verb_name + " " + place_name, float(option.score)])
		return out
	for a: String in ACTIONS:
		var s: float = _score(a)
		if s >= 0.0:
			out.append([a, s])
	out.sort_custom(func(x: Array, y: Array) -> bool: return x[1] > y[1])
	return out


func _best_action() -> Array:
	var best: String = "groom"
	var best_s: float = -INF
	for a: String in ACTIONS:
		var s: float = _score(a) + _rng.randf() * 0.08
		if s > best_s:
			best_s = s
			best = a
	return [best, best_s]


func _decide() -> void:
	if experimental_mode and free_brain != null:
		free_brain.choose()
		return
	var b: Array = _best_action()
	_start(b[0])


func _maybe_interrupt() -> void:
	if action == "eat" and is_instance_valid(_target):
		return
	var b: Array = _best_action()
	var cur: float = _score(action)
	if b[0] != action and float(b[1]) > cur + 0.3:
		_finish(true)
		_start(b[0])


func _start(a: String) -> void:
	action = a
	_act_time = 0.0
	_stuck_t = 0.0
	_special_t = 0.0
	_target = null
	_look_point = Vector2.INF
	_needs_start = needs.duplicate()
	stats.decisions = int(stats.decisions) + 1
	phase = Phase.MOVING
	_target_point = grid_pos
	var heat: float = _day_night.heat() if _day_night else 0.0
	match a:
		"eat":
			var f: Fish = _visible_fish()
			f.claimed = true
			_target = f
			_target_point = f.land_spot
			_act_duration = 2.5
			_think("¡Pescado!")
		"search_food":
			var spot: Vector2 = _recall_fish_spot()
			if spot != Vector2.INF:
				_target_point = spot
				_think("Aquí solía haber pescado...")
			else:
				var sh: Array = _island.random_shore(_rng)
				_target_point = sh[0]
				_look_point = sh[1]
				_think("Huele a mar...")
			_act_duration = 3.0
		"sleep":
			var bed: Node2D = _choose_bed()
			_target = bed
			_target_point = _spot_for(bed)
			_act_duration = _rng.randf_range(16.0, 26.0)
			_think("Tengo sueño...")
		"play_post":
			var post: Interactable = _interactables(Interactable.Kind.SCRATCH_POST)[0]
			_target = post
			_target_point = post.interact_point()
			_look_point = post.grid_pos
			_act_duration = _rng.randf_range(6.0, 9.0)
			_think("¡A rascar!")
		"play_ball":
			var ball: Interactable = _interactables(Interactable.Kind.TEMARI)[0]
			_target = ball
			_target_point = ball.interact_point()
			_act_duration = _rng.randf_range(7.0, 11.0)
			_think("¡La pelota!")
		"shade_rest":
			var tree: JpTree = _choose_tree()
			_target = tree
			_target_point = _spot_for(tree)
			_act_duration = _rng.randf_range(10.0, 16.0)
			_think("Qué calor..." if heat > 0.4 else "Un ratito a la sombra")
		"explore":
			_target_point = _explore_point()
			_act_duration = 1.8
			_think("¿Qué habrá por allí?")
		"watch_sea":
			var sh2: Array = _island.random_shore(_rng)
			_target_point = sh2[0]
			_look_point = sh2[1]
			_act_duration = _rng.randf_range(8.0, 12.0)
			_think("El mar...")
		"seek_light":
			var lamps: Array[Interactable] = _interactables(Interactable.Kind.LANTERN)
			lamps.sort_custom(func(x: Interactable, y: Interactable) -> bool: return grid_pos.distance_to(x.grid_pos) < grid_pos.distance_to(y.grid_pos))
			_target = lamps[0]
			_target_point = lamps[0].interact_point()
			_look_point = lamps[0].grid_pos
			_act_duration = 12.0
			_think("Está oscuro...")
		"interact":
			var bi: Array = _best_interaction()
			var th: Discoverable = bi[0]
			_int_verb = bi[1]
			_int_key = th.perceived_kind() + ":" + _int_verb
			_int_acc = {}
			_target = th
			_target_point = th.interact_point()
			_look_point = th.grid_pos
			_act_duration = {"sniff": 3.5, "dig": 5.0, "paw": 6.0, "bite": 4.0, "lie": 14.0}[_int_verb]
			if not knowledge.has(_int_key):
				_say(_pick("new"))
		_:
			phase = Phase.DOING
			_act_duration = 4.0
			_think("Lamer, lamer...")
	if not _island.is_walkable(_target_point):
		_target_point = grid_pos
	_repath()


func _repath() -> void:
	if not _island.is_walkable(grid_pos):
		grid_pos = _island.nearest_land(grid_pos)
	_path = _island.find_path(grid_pos, _target_point)


func _spot_for(node: Node2D) -> Vector2:
	if node is Interactable:
		return (node as Interactable).interact_point()
	var tree: JpTree = node as JpTree
	if tree:
		for i in 10:
			var p: Vector2 = tree.grid_pos + Vector2(_rng.randf_range(-0.9, 0.9), _rng.randf_range(0.3, 0.9))
			if _island.is_walkable(p):
				return p
		return tree.grid_pos
	return grid_pos


func _choose_bed() -> Node2D:
	var night: bool = _day_night != null and _day_night.is_night()
	var best: Node2D = null
	var best_s: float = -INF
	var candidates: Array[Node2D] = []
	for s: Interactable in _interactables(Interactable.Kind.SHELTER):
		candidates.append(s)
	for t: JpTree in _trees():
		candidates.append(t)
	for c: Node2D in candidates:
		var s: float = _aff(c) - grid_pos.distance_to((c as IsoEntity).grid_pos) * 0.05 + _rng.randf() * 0.25
		if c is Interactable and night:
			s += 0.8
		if c is JpTree and not night:
			s += 0.2
		if s > best_s:
			best_s = s
			best = c
	return best


func _choose_tree() -> JpTree:
	var best: JpTree = null
	var best_s: float = -INF
	for t: JpTree in _trees():
		var s: float = _aff(t) - grid_pos.distance_to(t.grid_pos) * 0.08 + _rng.randf() * 0.2
		if s > best_s:
			best_s = s
			best = t
	return best


func _explore_point() -> Vector2:
	var best: Vector2 = grid_pos
	var best_s: float = INF
	for i in 8:
		var p: Vector2 = _island.random_land_point(_rng, grid_pos, 7.0)
		var v: float = float(_visits.get(Vector2i(floori(p.x), floori(p.y)), 0))
		var s: float = v + p.distance_to(grid_pos) * 0.3
		if s < best_s:
			best_s = s
			best = p
	return best


# ================================================================ MEMORIA

func _recall_fish_spot() -> Vector2:
	if fish_memory.is_empty() or _rng.randf() > 0.85:
		return Vector2.INF
	var total: float = 0.0
	for m: Dictionary in fish_memory:
		total += float(m.n)
	var pick: float = _rng.randf() * total
	for m: Dictionary in fish_memory:
		pick -= float(m.n)
		if pick <= 0.0:
			return Vector2(float(m.x), float(m.y))
	return Vector2.INF


func _remember_fish(spot: Vector2) -> void:
	for m: Dictionary in fish_memory:
		if Vector2(float(m.x), float(m.y)).distance_to(spot) < 1.5:
			m.n = float(m.n) + 1.0
			return
	fish_memory.append({"x": spot.x, "y": spot.y, "n": 1.0})
	_log("Memoriza un nuevo lugar donde aparece pescado.")


func _mark_visit() -> void:
	var cell: Vector2i = Vector2i(floori(grid_pos.x), floori(grid_pos.y))
	if cell != _last_cell:
		_last_cell = cell
		_visits[cell] = int(_visits.get(cell, 0)) + 1


# ================================================================ EJECUCIÓN

func _move(delta: float) -> void:
	if _path.is_empty():
		_path = [_target_point]
	var to: Vector2 = _path[0] - grid_pos
	var dist: float = to.length()
	if dist < 0.06:
		_path.pop_front()
		if _path.is_empty():
			phase = Phase.DOING
		return
	var urgent: bool = (action == "eat" and float(needs.hunger) < 35.0) or (action == "seek_light" and float(needs.safety) < 30.0)
	var spd: float = walk_speed * (1.8 if urgent else 1.0) * (0.75 if float(needs.energy) < 15.0 else 1.0)
	var step: Vector2 = to.normalized() * minf(spd * delta, dist)
	var moved: bool = false
	for s: Vector2 in [step, Vector2(step.x, 0), Vector2(0, step.y)]:
		if s.length() > 0.0001 and _island.is_walkable(grid_pos + s):
			grid_pos += s
			_face_dir(s)
			moved = true
			break
	pose = "walk"
	if not moved:
		_stuck_t += delta
		if _stuck_t > 1.0:
			_finish(true)
			_decide()


func _perform(delta: float) -> void:
	_act_time += delta
	if _look_point != Vector2.INF:
		_face_dir(_look_point - grid_pos)
	match action:
		"eat":
			pose = "eat"
			if not is_instance_valid(_target):
				_think("...se lo llevó el mar")
				_act_time = _act_duration
			else:
				var f: Fish = _target as Fish
				_face_dir(f.grid_pos - grid_pos)
				if _act_time >= _act_duration:
					needs.hunger = float(needs.hunger) + f.nutrition
					_remember_fish(f.land_spot)
					stats.fish_eaten = int(stats.fish_eaten) + 1
					if int(stats.fish_eaten) == 1:
						_log("¡Su primer pescado! Ahora sabe que el mar da comida.")
					f.queue_free()
					_target = null
					_think("Ñam ñam ♪")
		"search_food":
			pose = "sit"
			if int(_act_time * 1.2) % 2 == 0:
				facing = 1.0
			else:
				facing = -1.0
			if _visible_fish() != null:
				_act_time = _act_duration
		"sleep":
			pose = "sleep"
			needs.energy = float(needs.energy) + 4.5 * delta
			needs.comfort = float(needs.comfort) + 0.5 * delta
			var night: bool = _day_night != null and _day_night.is_night()
			if _act_time >= _act_duration and night and float(needs.energy) < 98.0 and float(needs.hunger) > 30.0:
				_act_duration += 5.0
			if float(needs.hunger) < 12.0:
				_act_time = _act_duration
		"play_post":
			pose = "scratch"
			needs.fun = float(needs.fun) + 7.0 * delta * clampf(_aff(_target), 0.5, 1.5)
			needs.energy = float(needs.energy) - 0.8 * delta
			if is_instance_valid(_target):
				(_target as Interactable).wiggle()
		"play_ball":
			pose = "play"
			needs.fun = float(needs.fun) + 9.0 * delta * clampf(_aff(_target), 0.5, 1.5)
			needs.energy = float(needs.energy) - 1.2 * delta
			_special_t += delta
			if _special_t > 1.3 and is_instance_valid(_target):
				_special_t = 0.0
				var ball: Interactable = _target as Interactable
				ball.nudge(_island, _rng)
				_target_point = ball.grid_pos + Vector2(-0.45, 0.25)
				if not _island.is_walkable(_target_point):
					_target_point = grid_pos
				_repath()
				phase = Phase.MOVING
			if is_instance_valid(_target):
				_face_dir((_target as IsoEntity).grid_pos - grid_pos)
		"shade_rest":
			pose = "sit" if _act_time < 3.0 else "loaf"
			needs.energy = float(needs.energy) + 1.5 * delta
		"explore":
			pose = "sit"
			needs.fun = float(needs.fun) + 2.5 * delta
		"watch_sea":
			pose = "sit"
			needs.fun = float(needs.fun) + 1.8 * delta
			needs.safety = float(needs.safety) + 0.5 * delta
		"seek_light":
			pose = "loaf"
		"interact":
			_perform_interact(delta)
		_:
			pose = "groom"
			needs.comfort = float(needs.comfort) + 3.0 * delta
			needs.fun = float(needs.fun) + 0.5 * delta
	_clamp_needs()
	if _act_time >= _act_duration:
		_finish(false)
		_decide()


## Hace el verbo elegido sobre la cosa; el MUNDO decide qué pasa.
func _perform_interact(delta: float) -> void:
	if not is_instance_valid(_target):
		_act_time = _act_duration
		return
	var th: Discoverable = _target as Discoverable
	var night: bool = _day_night != null and _day_night.is_night()
	match _int_verb:
		"sniff", "bite":
			pose = "eat"
		"dig":
			pose = "dig"
		"paw":
			pose = "play"
		"lie":
			pose = "sleep" if float(needs.energy) < 45.0 else "loaf"
	var r: Dictionary = th.respond(_int_verb, delta, night)
	if _int_key == "plant:sniff" and r.has("fun"):
		pose = "roll" # la matatabi lo vuelve loco
	for n: String in r:
		if n == "_once":
			continue
		var d: float = float(r[n]) * delta
		needs[n] = float(needs[n]) + d
		_int_acc[n] = float(_int_acc.get(n, 0.0)) + d
	if r.has("_once"):
		var once: Dictionary = r["_once"]
		for n2: String in once:
			needs[n2] = float(needs[n2]) + float(once[n2])
			_int_acc[n2] = float(_int_acc.get(n2, 0.0)) + float(once[n2])


## Aprende el efecto real de lo que probó: cuánto cambió cada necesidad por segundo.
func _learn_interaction() -> void:
	var t: float = maxf(_act_time, 1.0)
	var rate: Dictionary = {}
	for n: String in NEED_NAMES:
		rate[n] = float(_int_acc.get(n, 0.0)) / t
	var first: bool = not knowledge.has(_int_key)
	if first:
		knowledge[_int_key] = {"n": 1, "eff": rate}
	else:
		var k: Dictionary = knowledge[_int_key]
		k.n = int(k.n) + 1
		for n2: String in rate:
			k.eff[n2] = lerpf(float(k.eff.get(n2, 0.0)), float(rate[n2]), 0.4)
	var total: float = 0.0
	var best_n: String = ""
	var best_v: float = 0.0
	for n3: String in rate:
		total += float(rate[n3])
		if absf(float(rate[n3])) > absf(best_v):
			best_v = float(rate[n3])
			best_n = n3
	var parts: PackedStringArray = _int_key.split(":")
	var what: String = "%s %s" % [Discoverable.VERB_NAMES[parts[1]], Discoverable.KIND_NAMES.get(parts[0], "algo")]
	if total > 2.0:
		_say(_pick("love"))
		if is_instance_valid(_target) and not (String(_target.name) in known_spots):
			known_spots.append(String(_target.name))
	elif total < -0.5:
		_say(_pick("bad"))
	elif first:
		_say(_pick("meh"))
	if first:
		var effect: String = "no pasa nada"
		if absf(best_v) > 0.3:
			effect = "%s %s" % ["sube" if best_v > 0.0 else "baja", NEED_NAMES[best_n].to_lower()]
		_log("Descubre: %s → %s" % [what, effect])
	traits.curiosity = clampf(float(traits.curiosity) + (0.02 if total > 1.0 else -0.004), 0.05, 0.95)
	if parts[1] == "lie" and float(rate.safety) > 1.0:
		traits.bravery = clampf(float(traits.bravery) - 0.003, 0.05, 0.95)


## Evalúa el resultado de la acción y aprende de él.
func _finish(interrupted: bool) -> void:
	if experimental_mode:
		return
	if action == "" or _needs_start.is_empty():
		return
	if interrupted and phase == Phase.MOVING:
		if action == "eat" and is_instance_valid(_target):
			(_target as Fish).claimed = false
		return # no llegó a probarlo: no aprende nada
	if action == "interact":
		if _act_time > 0.5:
			_learn_interaction()
		_int_key = ""
		_int_verb = ""
		return
	var gained: float = 0.0
	var room: float = 0.0
	for n: String in PRIMARY[action]:
		gained += maxf(0.0, float(needs[n]) - float(_needs_start[n]))
		room += 100.0 - float(_needs_start[n])
	var outcome: float = clampf(gained / maxf(room * 0.6, 12.0), 0.0, 1.5)
	if action == "search_food":
		outcome = 1.0 if _visible_fish() != null else 0.1
	var old: float = float(learned.get(action, 1.0))
	var new_v: float = lerpf(old, 0.5 + outcome, 0.15)
	learned[action] = new_v
	if _target != null and is_instance_valid(_target) and not (_target is Fish):
		affinity[String(_target.name)] = lerpf(_aff(_target), 0.5 + outcome, 0.2)

	# Deriva de personalidad
	match action:
		"play_post", "play_ball":
			traits.playfulness = float(traits.playfulness) + 0.012 * (outcome - 0.4)
			stats.plays = int(stats.plays) + 1
		"sleep":
			traits.laziness = float(traits.laziness) + 0.004
			stats.naps = int(stats.naps) + 1
		"explore", "watch_sea", "search_food":
			traits.curiosity = float(traits.curiosity) + 0.012 * (outcome - 0.4)
		"eat":
			traits.laziness = float(traits.laziness) - 0.003
	if _day_night and _day_night.is_night() and not _in_shelter():
		traits.bravery = float(traits.bravery) + (0.006 if float(needs.safety) > 50.0 else -0.004)
	for k: String in traits:
		traits[k] = clampf(float(traits[k]), 0.05, 0.95)

	if absf(new_v - old) > 0.06:
		var verb: String = "le funciona" if new_v > old else "no le convence tanto"
		_log("Aprende: «%s» %s (%.2f)" % [ACTION_NAMES[action], verb, new_v])


func _face_dir(d: Vector2) -> void:
	var sd: Vector2 = Iso.to_screen(d)
	if absf(sd.x) > 0.001:
		facing = signf(sd.x)


func _think(t: String) -> void:
	thought = t
	last_thought = t
	_thought_time = 3.5


func _log(t: String) -> void:
	var stamp: String = ""
	if _day_night:
		stamp = "D%d %s  " % [_day_night.day, _day_night.time_string()]
	log_lines.append(stamp + t)
	while log_lines.size() > 7:
		log_lines.pop_front()


func _on_new_day(_d: int) -> void:
	stats.days = int(stats.days) + 1
	_log("Sobrevive un día más en la isla (%d en total)." % int(stats.days))


# ================================================================ PERSISTENCIA

func _reset_learned() -> void:
	learned.clear()
	for a: String in ACTIONS:
		learned[a] = 1.0


func _save_brain() -> void:
	if experimental_mode:
		if free_brain != null:
			free_brain.save()
		return
	if not persist_brain:
		return
	var data: Dictionary = {"learned": learned, "affinity": affinity, "traits": traits, "fish_memory": fish_memory, "stats": stats,
		"knowledge": knowledge, "known_spots": known_spots}
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func _load_brain() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		return
	var d: Dictionary = parsed
	for key: String in ["learned", "affinity", "traits", "stats"]:
		if d.has(key) and d[key] is Dictionary:
			var target_dict: Dictionary = get(key)
			target_dict.merge(d[key], true)
	if d.has("fish_memory") and d.fish_memory is Array:
		fish_memory = d.fish_memory
	if d.has("knowledge") and d.knowledge is Dictionary:
		knowledge = d.knowledge
	if d.has("known_spots") and d.known_spots is Array:
		known_spots = d.known_spots


func reset_brain() -> void:
	if experimental_mode and free_brain != null:
		free_brain.reset()
		_log("Experimento reiniciado sin conocimiento previo.")
		return
	_reset_learned()
	affinity.clear()
	fish_memory.clear()
	knowledge.clear()
	known_spots.clear()
	_visits.clear()
	traits = {"curiosity": 0.5, "playfulness": 0.5, "laziness": 0.5, "bravery": 0.5}
	stats = {"fish_eaten": 0, "naps": 0, "plays": 0, "days": 0, "decisions": 0}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	log_lines.clear()
	_log("Memoria borrada. Un gatito nuevo descubre la isla.")


# ================================================================ DIBUJO
# El gato es un AnimatedSprite2D (arte pintado en res://assets/cat/).
# Este nodo dibuja la sombra; un hijo "Overlay" dibuja encima los globos,
# las zetas y el polvo.

## Animaciones: archivo, fotogramas por segundo, punto de apoyo (patas) en el fotograma de 256 px.
const ANIMS = {
	"walk": [8.0, Vector2(116, 246)],
	"eat": [4.0, Vector2(121, 250)],
	"play": [7.0, Vector2(136, 251)],
	"dig": [8.0, Vector2(145, 250)],
	"idle": [2.5, Vector2(122, 249)],
	"groom": [4.0, Vector2(123, 251)],
	"sleep": [1.5, Vector2(118, 216)],
}
const FRAME = 112.0       # tamaño del fotograma en las hojas de res://assets/cat/
const ART = 256.0         # tamaño original con el que se midieron los puntos de apoyo
const POSE_ANIM = {
	"walk": "walk", "eat": "eat", "dig": "dig", "play": "play", "scratch": "play",
	"sit": "idle", "groom": "groom", "sleep": "sleep", "loaf": "sleep", "roll": "play",
}

## Tamaño del gato en pantalla (alto aproximado en píxeles al zoom 1).
@export var sprite_height: float = 46.0

var _sprite: AnimatedSprite2D
var _overlay: Node2D


func _build_sprite() -> void:
	if _sprite != null:
		return
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	for anim: String in ANIMS:
		var tex: Texture2D = load("res://assets/cat/%s.png" % anim) as Texture2D
		if tex == null:
			continue
		frames.add_animation(anim)
		frames.set_animation_speed(anim, float(ANIMS[anim][0]))
		frames.set_animation_loop(anim, true)
		var n: int = int(tex.get_width() / FRAME)
		for k in n:
			var at: AtlasTexture = AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(k * FRAME, 0, FRAME, FRAME)
			frames.add_frame(anim, at)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = frames
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)
	_overlay = Node2D.new()
	_overlay.name = "Overlay"
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_apply_pose(0.0)


## Elige animación según la pose, orienta el sprite y lo apoya en el suelo.
func _apply_pose(delta: float) -> void:
	if _sprite == null:
		return
	var anim: String = "idle" if experimental_mode and pose == "loaf" else POSE_ANIM.get(pose, "idle")
	if not _sprite.sprite_frames.has_animation(anim):
		return
	if _sprite.animation != anim:
		_sprite.play(anim)
	elif not _sprite.is_playing():
		_sprite.play(anim)
	var k: float = sprite_height / 240.0 * ART / FRAME
	_sprite.scale = Vector2(k, k)
	# el arte mira a la izquierda; facing > 0 = hacia la derecha de la pantalla
	var flip: bool = facing > 0.0
	if pose == "roll" and sin(_anim_t * 1.5) < 0.0:
		flip = not flip
	_sprite.flip_h = flip
	var anchor: Vector2 = ANIMS[anim][1] * (FRAME / ART)
	if flip:
		anchor.x = FRAME - anchor.x
	_sprite.offset = -anchor
	_sprite.position = Vector2(0, -_lift)
	match pose:
		"scratch":
			_sprite.rotation = -0.45 * facing
		"roll":
			_sprite.rotation = sin(_anim_t * 3.0) * 0.5
		_:
			_sprite.rotation = 0.0
	# al caminar más rápido, las patas también
	if anim == "walk":
		_sprite.speed_scale = 1.0 if delta <= 0.0 else clampf(walk_speed / 1.4, 0.7, 1.8)
	_overlay.queue_redraw()


func _draw() -> void:
	draw_shadow(sprite_height * (0.42 if pose == "sleep" or pose == "loaf" else 0.33), Vector2(0, -_lift), 0.28)


func _draw_overlay() -> void:
	var o: Vector2 = Vector2(0, -_lift)
	if pose == "dig":
		for i in 4:
			var k: float = fmod(_anim_t * 2.5 + float(i) * 0.25, 1.0)
			_overlay.draw_circle(o + Vector2(-facing * (8.0 + k * 12.0), -2.0 - sin(k * PI) * 9.0), 1.3, Color(0.55, 0.42, 0.28, 1.0 - k))
	if pose == "sleep":
		_draw_zzz(o)
	if _thought_time > 0.0 and thought != "":
		_draw_bubble(thought, o + Vector2(0, -sprite_height - 8.0))


func _draw_zzz(o: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	for i in 3:
		var k: float = fmod(_anim_t * 0.5 + float(i) / 3.0, 1.0)
		var p: Vector2 = o + Vector2(-facing * 8.0 + k * 10.0, -sprite_height * 0.55 - k * 22.0)
		_overlay.draw_string(font, p, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 + k * 6), Color(1, 1, 1, 1.0 - k))


func _draw_bubble(text: String, at: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	var fs: int = 11
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var rect: Rect2 = Rect2(at - Vector2(size.x * 0.5 + 6, size.y + 4), Vector2(size.x + 12, size.y + 6))
	var a: float = clampf(_thought_time, 0.0, 1.0)
	_overlay.draw_rect(rect, Color(0.98, 0.95, 0.88, 0.92 * a))
	_overlay.draw_rect(rect, Color(INK, a), false, 1.2)
	_overlay.draw_colored_polygon(PackedVector2Array([Vector2(at.x - 3, rect.end.y), Vector2(at.x + 3, rect.end.y), Vector2(at.x, rect.end.y + 5)]), Color(0.98, 0.95, 0.88, 0.92 * a))
	_overlay.draw_string(font, Vector2(rect.position.x + 6, rect.end.y - 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(INK, a))
