class_name FreeCatBrain
extends Node
## Experimento: sin utilidades por objeto ni necesidades asociadas a verbos.
## Conoce solo efectos netos experimentados; no consulta FreeCatEffects al elegir.
const Effects = preload("res://scripts/world/free_cat_effects.gd")
const VERBS = ["sniff", "dig", "paw", "bite", "lie", "groom"]
const MEMORY_PATH = "user://gatito_free_brain_v1.json"

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
			places = parsed.get("places", {})
			completed_trials = int(parsed.get("completed_trials", 0))
	cat._log("Experimento libre: sin soluciones conocidas. Semilla %d." % actual_seed)
	choose()

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
			places[String(entity.get_path())] = {"x": point.x, "y": point.y, "seen": true}

func candidate(key: String, verb: String, point: Vector2, path: String) -> Dictionary:
	var count: int = int(memory.get(key, {}).get("n", 0))
	var score: float = curiosity / sqrt(float(count + 1))
	var effects: Dictionary = memory.get(key, {}).get("effects", {})
	for need: String in cat.needs:
		var urgency: float = pow(1.0 - float(cat.needs[need]) / 100.0, 1.6)
		score += float(effects.get(need, 0.0)) * (urgency + 0.05) * float(need_weights.get(need, 1.0)) / 5.0
	score -= cat.grid_pos.distance_to(point) * travel_cost
	return {"key": key, "verb": verb, "x": point.x, "y": point.y, "path": path, "score": score}

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
			options.append(candidate(zone + ":" + verb + ":" + ctx, verb, point, ""))
	for path: String in places:
		var spot: Dictionary = places[path]
		var point: Vector2 = Vector2(float(spot.x), float(spot.y))
		# No busca el nodo para actualizar su posición fuera del campo perceptivo.
		for verb: String in VERBS:
			options.append(candidate(path + ":" + verb + ":" + ctx, verb, point, path))
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
			finish_trial()
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
	if elapsed >= trial_seconds or effects.has("_once"):
		finish_trial()
		choose()

func finish_trial() -> void:
	if not active or elapsed < 0.1:
		return
	var key: String = choice.key
	var entry: Dictionary = memory.get(key, {"n": 0, "effects": {}})
	var measured: Dictionary = {}
	for need: String in baseline:
		measured[need] = (float(cat.needs[need]) - float(baseline[need])) / elapsed
		entry.effects[need] = lerpf(float(entry.effects.get(need, measured[need])), float(measured[need]), learning_rate)
	entry.n = int(entry.n) + 1
	memory[key] = entry
	completed_trials += 1
	history.append({"time": elapsed_world, "key": key, "duration": elapsed, "changes_per_second": measured, "needs": cat.needs.duplicate()})
	if history.size() > 200:
		history.pop_front()
	cat._log("Ensayo %d: %s (sin resultado prefijado)." % [completed_trials, label])
	active = false

func report() -> Dictionary:
	return {"version": 1, "seed": actual_seed, "completed_trials": completed_trials,
		"parameters": {"curiosity": curiosity, "random_choice": random_choice, "learning_rate": learning_rate, "perception_radius": perception_radius, "travel_cost": travel_cost, "trial_seconds": trial_seconds, "need_weights": need_weights},
		"minimums": minimums, "memory": memory, "places": places, "recent_trials": history}

func save() -> void:
	if not is_instance_valid(cat) or not cat.persist_brain:
		return
	var file: FileAccess = FileAccess.open(MEMORY_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report(), "\t"))

func reset() -> void:
	memory.clear()
	places.clear()
	history.clear()
	completed_trials = 0
	minimums = cat.needs.duplicate()
	elapsed_world = 0.0
	rng.seed = actual_seed
	choose()
	save()
