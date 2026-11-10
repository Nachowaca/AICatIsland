class_name FreeCatBrain
extends Node
## Experimento: sin utilidades por objeto ni necesidades asociadas a verbos.
## Conoce solo efectos netos experimentados; no consulta FreeCatEffects al elegir.
const Effects = preload("res://scripts/world/free_cat_effects.gd")
const VERBS = ["sniff", "dig", "paw", "bite", "lie", "groom"]
const MEMORY_PATH = "user://gatito_free_brain_v1.json"

## Horas de isla despierto para gastar 90 de energía, sin efectos adicionales.
@export_range(0.1, 48.0) var awake_island_hours: float = 8.0
@export_range(0.01, 20.0) var sleep_recovery_per_second: float = 4.5
@export_range(10.0, 100.0) var sleep_wake_energy: float = 85.0
## Tiempo despierto para gastar 100 de saciedad; no asigna comida a ningún verbo.
@export_range(1.0, 60.0) var satiety_minutes: float = 6.0
@export var experiment_seed: int = 0
@export_range(0.0, 3.0) var curiosity: float = 0.7
@export_range(0.0, 1.0) var random_choice: float = 0.15
@export_range(0.01, 1.0) var learning_rate: float = 0.35
@export_range(1.0, 15.0) var perception_radius: float = 5.0
@export_range(0.0, 0.3) var travel_cost: float = 0.035
@export_range(2.0, 15.0) var trial_seconds: float = 6.0
@export var need_weights: Dictionary = {"hunger": 1.0, "energy": 1.0, "fun": 1.0, "safety": 1.0, "comfort": 1.0}

var cat: Node2D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var actual_seed: int = 0
var memory: Dictionary = {}
## Efectos experimentados por apariencia + verbo, reutilizables entre ejemplares/contextos.
var models: Dictionary = {}
var places: Dictionary = {}
var history: Array = []
var rankings: Array = []
var choice: Dictionary = {}
var elapsed: float = 0.0
var baseline: Dictionary = {}
var active: bool = false
var completed_trials: int = 0
var label: String = "Observando"
var minimums: Dictionary = {}
var elapsed_world: float = 0.0
var _save_timer: float = 0.0
var sleeping: bool = false
var sleep_blocked: bool = false
var _loaded_report: Dictionary = {}
var voice: VoiceObserver = VoiceObserver.new()
## Señal de una nueva partida; conserva memoria aprendida pero no necesidades previas.
var start_needs_full: bool = false

func setup(host: Node2D) -> void:
	cat = host
	if experiment_seed == 0:
		rng.randomize()
		actual_seed = rng.randi_range(1, 2000000000)
		rng.seed = actual_seed
	else:
		actual_seed = experiment_seed
		rng.seed = actual_seed
	minimums = cat.needs.duplicate()
	if cat.persist_brain and FileAccess.file_exists(MEMORY_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MEMORY_PATH))
		if parsed is Dictionary:
			_loaded_report = parsed.duplicate(true)
			if not start_needs_full:
				if parsed.get("needs", null) is Dictionary:
					for need: String in cat.needs:
						if parsed.needs.has(need):
							cat.needs[need] = clampf(float(parsed.needs[need]), 0.0, 100.0)
				sleeping = bool(parsed.get("sleeping", false))
				sleep_blocked = bool(parsed.get("sleep_blocked", false))
			memory = parsed.get("memory", {})
			models = parsed.get("models", {})
			voice.seen_actions = parsed.get("voice_actions", {})
			voice.seen_discoveries = parsed.get("voice_discoveries", {})
			places = parsed.get("places", {})
			completed_trials = int(parsed.get("completed_trials", 0))
	cat._log("Experimento libre: sin soluciones conocidas. Semilla %d." % actual_seed)
	choose()
	if start_needs_full:
		save() # Nueva partida: conserva lo aprendido, pero inicia necesidades/sueño nuevos.

func energy_decay_per_second() -> float:
	var day_seconds: float = 240.0
	if is_instance_valid(cat) and cat._day_night != null:
		day_seconds = maxf(float(cat._day_night.day_length_sec), 0.01)
	return 90.0 / (day_seconds * maxf(awake_island_hours, 0.1) / 24.0)

## La interrupción queda bloqueada hasta que ambas necesidades se recuperen.
func update_sleep_state() -> bool:
	var critical: bool = float(cat.needs.hunger) < 10.0 or float(cat.needs.safety) < 10.0
	if sleep_blocked and float(cat.needs.hunger) >= 20.0 and float(cat.needs.safety) >= 20.0:
		sleep_blocked = false
	if sleeping:
		if critical:
			sleeping = false
			sleep_blocked = true
		elif float(cat.needs.energy) >= maxf(sleep_wake_energy, 10.0):
			sleeping = false
	elif float(cat.needs.energy) < 10.0 and not critical and not sleep_blocked:
		sleeping = true
		active = false # Ensayo incompleto: nunca aprender del sueño.
	return sleeping

func critical_urgency() -> float:
	var lowest: float = minf(float(cat.needs.hunger), float(cat.needs.safety))
	return clampf((35.0 - lowest) / 35.0, 0.0, 1.0)

func satiety_decay_per_second() -> float:
	return 100.0 / (maxf(satiety_minutes, 1.0) * 60.0)

## Etiquetas perceptivas, nunca efectos ni la propiedad nutrition del objeto.
static func appearance_key(entity: IsoEntity) -> String:
	if entity is Discoverable:
		return "visible_" + (entity as Discoverable).perceived_kind()
	if entity is Fish:
		return "silver_long_shape"
	if entity is Interactable:
		return "structure_%d" % int((entity as Interactable).kind)
	if entity is JpTree:
		return "canopy_%d" % int((entity as JpTree).kind)
	return "unknown_shape"

func context() -> String:
	var night: bool = cat._day_night != null and cat._day_night.is_night()
	var hot: bool = cat._day_night != null and cat._day_night.heat() > 0.3
	return ("noche" if night else "dia") + ("_calor" if hot else "_fresco")

func observe() -> void:
	for group: String in ["discoverable", "interactable", "shade", "fish"]:
		for node: Node in cat.get_tree().get_nodes_in_group(group):
			if not node is IsoEntity or node.is_queued_for_deletion():
				continue
			var entity: IsoEntity = node as IsoEntity
			if cat.grid_pos.distance_to(entity.grid_pos) > perception_radius:
				continue
			var point: Vector2 = entity.grid_pos
			if entity is Fish:
				point = (entity as Fish).land_spot
			elif entity.has_method("interact_point"):
				point = entity.interact_point()
			places[String(entity.get_path())] = {"x": point.x, "y": point.y, "seen": true, "appearance": appearance_key(entity)}

func candidate(key: String, verb: String, point: Vector2, path: String, appearance: String = "") -> Dictionary:
	var model_key: String = appearance + ":" + verb if appearance != "" else ""
	var local: Dictionary = memory.get(key, {})
	var general: Dictionary = models.get(model_key, {})
	var count: int = maxi(int(local.get("n", 0)), int(general.get("n", 0)))
	var critical: float = critical_urgency()
	var score: float = curiosity * (1.0 - 0.9 * critical) / sqrt(float(count + 1))
	# Combina lo vivido aquí con lo experimentado en ejemplares parecidos.
	var effects: Dictionary = (general.get("effects", {}) as Dictionary).duplicate()
	var local_effects: Dictionary = local.get("effects", {})
	for need: String in local_effects:
		effects[need] = lerpf(float(effects[need]), float(local_effects[need]), 0.6) if effects.has(need) else local_effects[need]
	for need: String in cat.needs:
		var urgency: float = pow(1.0 - float(cat.needs[need]) / 100.0, 1.6)
		var priority: float = 1.0
		if need == "hunger" or need == "safety":
			priority += 4.0 * clampf((35.0 - float(cat.needs[need])) / 35.0, 0.0, 1.0)
		score += float(effects.get(need, 0.0)) * (urgency + 0.05) * priority * float(need_weights.get(need, 1.0)) / 5.0
	score -= cat.grid_pos.distance_to(point) * travel_cost
	var evidence: String = "local" if not local.is_empty() else ("similar" if not general.is_empty() else "unknown")
	return {"key": key, "model_key": model_key, "evidence": evidence, "verb": verb, "x": point.x, "y": point.y, "path": path, "score": score}

func candidates() -> Array:
	var options: Array = []
	var ctx: String = context()
	# El suelo se recuerda por zona; no recibe etiquetas como «seguro» o «sombra».
	var points: Array[Vector2] = [cat.grid_pos]
	for i in 4:
		points.append(cat._island.random_land_point(rng, cat.grid_pos, perception_radius))
	for point: Vector2 in points:
		var zone: String = "suelo_%d_%d" % [floori(point.x / 3.0), floori(point.y / 3.0)]
		for verb: String in VERBS:
			options.append(candidate(zone + ":" + verb + ":" + ctx, verb, point, "", "ground"))
	for path: String in places:
		var spot: Dictionary = places[path]
		var point: Vector2 = Vector2(float(spot.x), float(spot.y))
		# No busca el nodo para actualizar su posición fuera del campo perceptivo.
		for verb: String in VERBS:
			options.append(candidate(path + ":" + verb + ":" + ctx, verb, point, path, String(spot.get("appearance", ""))))
	return options

func choose() -> void:
	observe()
	var options: Array = candidates()
	# Fisher-Yates con RNG propio: el azar del mundo no decide los empates.
	for i in range(options.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Dictionary = options[i]
		options[i] = options[j]
		options[j] = swap
	var best: Dictionary = options[0]
	for option: Dictionary in options:
		if float(option.score) > float(best.score):
			best = option
	if rng.randf() < random_choice * (1.0 - 0.9 * critical_urgency()):
		best = options[rng.randi_range(0, options.size() - 1)]
	choice = best.duplicate()
	rankings = options.duplicate()
	rankings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
	cat.action = "free"
	cat._target_point = Vector2(choice.x, choice.y)
	cat._target = null
	cat._repath()
	cat.phase = 0 # MOVING: solo usa el motor de desplazamiento existente
	elapsed = 0.0
	active = false
	label = "%s · %s" % [choice.verb, "suelo" if choice.path == "" else String(choice.path).get_file()]

func _tick_voice(allow_sleep: bool = false) -> void:
	if sleeping and not allow_sleep:
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if not sleeping:
		var night: bool = cat._day_night != null and cat._day_night.is_night()
		voice.periodic(cat.needs, night, not memory.is_empty(), now)
	var text: String = voice.next(now)
	if text != "":
		cat._say(text)

func tick(dt: float) -> void:
	elapsed_world += dt
	_tick_voice()
	for need: String in cat.needs:
		minimums[need] = minf(float(minimums.get(need, 100.0)), float(cat.needs[need]))
	_save_timer += dt
	if _save_timer >= 20.0:
		_save_timer = 0.0
		save()
	var was_sleeping: bool = sleeping
	if update_sleep_state():
		if not was_sleeping:
			voice.enqueue(CatVoice.SLEEP, 3)
			_tick_voice(true)
		cat.action = "free_sleep"
		cat.phase = 1
		cat.pose = "sleep"
		label = "Durmiendo"
		cat.needs.energy = float(cat.needs.energy) + sleep_recovery_per_second * dt
		cat._clamp_needs()
		return
	if was_sleeping:
		voice.enqueue(CatVoice.WAKE, 2)
		cat.pose = "sit"
		choose()
		return
	if cat.phase == 0:
		cat._move(dt)
		return
	if not active:
		baseline = cat.needs.duplicate()
		active = true
		voice.action_started(String(choice.get("verb", "")))
	elapsed += dt
	var verb: String = choice.get("verb", "sniff")
	cat.pose = {"sniff": "eat", "bite": "eat", "dig": "dig", "paw": "play", "lie": "sit", "groom": "groom"}[verb]
	var target: Node2D = null
	if choice.path != "":
		target = cat.get_node_or_null(NodePath(choice.path)) as Node2D
		if not is_instance_valid(target) or target.is_queued_for_deletion() or cat.grid_pos.distance_to(target.grid_pos) > 2.0:
			places.erase(choice.path)
			# No confundir ausencia del objeto con prueba de un efecto físico nulo.
			active = false
			choose()
			return
	var night: bool = cat._day_night != null and cat._day_night.is_night()
	var before_appearance: String = appearance_key(target as IsoEntity) if target is Discoverable else ""
	var effects: Dictionary = Effects.respond(target, verb, dt, elapsed, night)
	if target is Discoverable:
		var after_appearance: String = appearance_key(target as IsoEntity)
		if after_appearance != before_appearance:
			voice.discovery(after_appearance)
	for need: String in effects:
		if need != "_once":
			cat.needs[need] = float(cat.needs[need]) + float(effects[need]) * dt
	if effects.has("_once"):
		voice.result(effects["_once"])
	for need: String in effects.get("_once", {}):
		cat.needs[need] = float(cat.needs[need]) + float(effects._once[need])
	cat._clamp_needs()
	if is_instance_valid(target) and target.is_queued_for_deletion():
		places.erase(choice.path)
		if target is Fish:
			cat.stats.fish_eaten = int(cat.stats.fish_eaten) + 1 # Observación, no preferencia.
	if elapsed >= trial_seconds or effects.has("_once"):
		finish_trial()
		choose()

func _record_effects(store: Dictionary, key: String, measured: Dictionary) -> void:
	var entry: Dictionary = store.get(key, {"n": 0, "effects": {}})
	for need: String in measured:
		var observed: float = float(measured[need])
		var previous: float = float(entry.effects.get(need, observed))
		# Un límite de la barra da una cota, no demuestra un efecto menor que el recordado.
		if float(cat.needs[need]) >= 100.0:
			observed = maxf(previous, observed)
		elif float(cat.needs[need]) <= 0.0:
			observed = minf(previous, observed)
		entry.effects[need] = lerpf(previous, observed, learning_rate)
	entry.n = int(entry.n) + 1
	store[key] = entry

func finish_trial() -> void:
	if not active or elapsed < 0.1:
		return
	var key: String = choice.key
	var measured: Dictionary = {}
	for need: String in baseline:
		var before: float = float(baseline[need])
		var after: float = float(cat.needs[need])
		if (before <= 0.0 and after <= 0.0) or (before >= 100.0 and after >= 100.0):
			continue # No sentir variación en una barra saturada no equivale a efecto nulo.
		measured[need] = (after - before) / elapsed
	if float(measured.get("fun", 0.0)) > 1.0:
		voice.enqueue(CatVoice.FUN_POSITIVE, 2)
	_record_effects(memory, key, measured)
	var model_key: String = choice.get("model_key", "")
	if model_key != "":
		_record_effects(models, model_key, measured)
	completed_trials += 1
	history.append({"time": elapsed_world, "key": key, "model_key": model_key, "evidence": choice.get("evidence", "unknown"), "duration": elapsed, "changes_per_second": measured, "needs": cat.needs.duplicate()})
	if history.size() > 200:
		history.pop_front()
	cat._log("Ensayo %d: %s (sin resultado prefijado)." % [completed_trials, label])
	active = false

func report() -> Dictionary:
	var data: Dictionary = _loaded_report.duplicate(true)
	data.merge({"version": 3, "seed": actual_seed, "completed_trials": completed_trials,
		"parameters": {"awake_island_hours": awake_island_hours, "sleep_recovery_per_second": sleep_recovery_per_second, "sleep_wake_energy": sleep_wake_energy, "satiety_minutes": satiety_minutes, "curiosity": curiosity, "random_choice": random_choice, "learning_rate": learning_rate, "perception_radius": perception_radius, "travel_cost": travel_cost, "trial_seconds": trial_seconds, "need_weights": need_weights},
		"needs": cat.needs.duplicate(), "sleeping": sleeping, "sleep_blocked": sleep_blocked,
		"minimums": minimums, "memory": memory, "models": models, "places": places, "recent_trials": history,
		"voice_actions": voice.seen_actions, "voice_discoveries": voice.seen_discoveries}, true)
	return data

func save() -> void:
	if not is_instance_valid(cat) or not cat.persist_brain:
		return
	var file: FileAccess = FileAccess.open(MEMORY_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report(), "\t"))

func reset() -> void:
	memory.clear()
	models.clear()
	voice.seen_actions.clear()
	voice.seen_discoveries.clear()
	voice.pending.clear()
	places.clear()
	history.clear()
	completed_trials = 0
	minimums = cat.needs.duplicate()
	elapsed_world = 0.0
	rng.seed = actual_seed
	choose()
	save()
