class_name FreeCatBrain
extends Node
## Experimento: sin utilidades por objeto ni necesidades asociadas a verbos.
## Conoce solo efectos netos experimentados; no consulta FreeCatEffects al elegir.
const Effects = preload("res://scripts/world/free_cat_effects.gd")
const VERBS = ["sniff", "dig", "paw", "bite", "lie", "groom"]
const MEMORY_PATH = "user://gatito_free_brain_v1.json"

## Minutos de juego para gastar 100 de energía despierto, sin esfuerzos adicionales.
@export_range(1.0, 60.0) var fatigue_minutes: float = 10.0
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
			memory = parsed.get("memory", {})
			models = parsed.get("models", {})
			places = parsed.get("places", {})
			completed_trials = int(parsed.get("completed_trials", 0))
	cat._log("Experimento libre: sin soluciones conocidas. Semilla %d." % actual_seed)
	choose()

func energy_decay_per_second() -> float:
	return 100.0 / (maxf(fatigue_minutes, 1.0) * 60.0)

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
	var score: float = curiosity / sqrt(float(count + 1))
	# Combina lo vivido aquí con lo experimentado en ejemplares parecidos.
	var effects: Dictionary = (general.get("effects", {}) as Dictionary).duplicate()
	var local_effects: Dictionary = local.get("effects", {})
	for need: String in local_effects:
		effects[need] = lerpf(float(effects[need]), float(local_effects[need]), 0.6) if effects.has(need) else local_effects[need]
	for need: String in cat.needs:
		var urgency: float = pow(1.0 - float(cat.needs[need]) / 100.0, 1.6)
		score += float(effects.get(need, 0.0)) * (urgency + 0.05) * float(need_weights.get(need, 1.0)) / 5.0
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
	if rng.randf() < random_choice:
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

func tick(dt: float) -> void:
	elapsed_world += dt
	for need: String in cat.needs:
		minimums[need] = minf(float(minimums.get(need, 100.0)), float(cat.needs[need]))
	_save_timer += dt
	if _save_timer >= 20.0:
		_save_timer = 0.0
		save()
	if cat.phase == 0:
		cat._move(dt)
		return
	if not active:
		baseline = cat.needs.duplicate()
		active = true
	elapsed += dt
	var verb: String = choice.get("verb", "sniff")
	cat.pose = {"sniff": "eat", "bite": "eat", "dig": "dig", "paw": "play", "lie": "sleep", "groom": "groom"}[verb]
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
	var effects: Dictionary = Effects.respond(target, verb, dt, elapsed, night)
	for need: String in effects:
		if need != "_once":
			cat.needs[need] = float(cat.needs[need]) + float(effects[need]) * dt
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
	return {"version": 2, "seed": actual_seed, "completed_trials": completed_trials,
		"parameters": {"fatigue_minutes": fatigue_minutes, "satiety_minutes": satiety_minutes, "curiosity": curiosity, "random_choice": random_choice, "learning_rate": learning_rate, "perception_radius": perception_radius, "travel_cost": travel_cost, "trial_seconds": trial_seconds, "need_weights": need_weights},
		"minimums": minimums, "memory": memory, "models": models, "places": places, "recent_trials": history}

func save() -> void:
	if not is_instance_valid(cat) or not cat.persist_brain:
		return
	var file: FileAccess = FileAccess.open(MEMORY_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report(), "\t"))

func reset() -> void:
	memory.clear()
	models.clear()
	places.clear()
	history.clear()
	completed_trials = 0
	minimums = cat.needs.duplicate()
	elapsed_world = 0.0
	rng.seed = actual_seed
	choose()
	save()
