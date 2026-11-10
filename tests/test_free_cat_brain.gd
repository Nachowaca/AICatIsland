class_name TestFreeCatBrain
extends Node
## Contratos del selector y medición; no sustituyen la observación en vivo.

class BodyStub:
	extends Node2D
	var needs: Dictionary = {"hunger": 10.0, "energy": 50.0, "fun": 50.0, "safety": 50.0, "comfort": 50.0}
	var grid_pos: Vector2 = Vector2.ZERO
	var persist_brain: bool = false
	var _day_night: DayNight = null
	func _log(_message: String) -> void:
		pass

func test_desgaste_ocho_horas_isla() -> void:
	var brain: FreeCatBrain = FreeCatBrain.new()
	var body: BodyStub = BodyStub.new()
	var clock: DayNight = DayNight.new()
	brain.cat = body
	body._day_night = clock
	for day: float in [240.0, 2400.0, 120.0]:
		clock.day_length_sec = day
		assert(is_equal_approx(brain.energy_decay_per_second() * day / 3.0, 90.0))
		for speed: float in [1.0, 4.0, 10.0]:
			assert(is_equal_approx(brain.energy_decay_per_second() * (day / 3.0 / speed) * speed, 90.0))
	brain.free()
	body.free()
	clock.free()

func test_no_nace_sabiendo_que_morder_alimenta() -> void:
	var body: BodyStub = BodyStub.new()
	var brain: FreeCatBrain = FreeCatBrain.new()
	brain.cat = body
	brain.curiosity = 0.0
	brain.travel_cost = 0.0
	var bite: Dictionary = brain.candidate("pescado:bite:dia", "bite", Vector2.ZERO, "", "silver_long_shape")
	var sniff: Dictionary = brain.candidate("pescado:sniff:dia", "sniff", Vector2.ZERO, "", "silver_long_shape")
	assert(is_equal_approx(float(bite.score), float(sniff.score)), "Hambre no debe conceder conocimiento innato del pescado")
	assert(brain.memory.is_empty())
	brain.free()
	body.free()

func test_aprende_cambio_neto_y_puede_desaprender() -> void:
	var body: BodyStub = BodyStub.new()
	var brain: FreeCatBrain = FreeCatBrain.new()
	brain.cat = body
	brain.learning_rate = 1.0
	brain.curiosity = 0.0
	brain.travel_cost = 0.0
	brain.choice = {"key": "objeto:bite:dia"}
	brain.baseline = body.needs.duplicate()
	brain.active = true
	brain.elapsed = 5.0
	body.needs.hunger = 35.0
	body.needs.energy = 45.0
	brain.finish_trial()
	assert(is_equal_approx(float(brain.memory["objeto:bite:dia"].effects.hunger), 5.0))
	assert(is_equal_approx(float(brain.memory["objeto:bite:dia"].effects.energy), -1.0))
	var helpful: Dictionary = brain.candidate("objeto:bite:dia", "bite", Vector2.ZERO, "")
	assert(float(helpful.score) > 0.0)
	brain.baseline = body.needs.duplicate()
	brain.active = true
	body.needs.hunger = 10.0
	brain.finish_trial()
	var harmful: Dictionary = brain.candidate("objeto:bite:dia", "bite", Vector2.ZERO, "")
	assert(float(harmful.score) < 0.0, "Una experiencia negativa debe poder invertir una preferencia")
	assert(brain.completed_trials == 2)
	assert(brain.history.size() == 2)
	brain.free()
	body.free()

func test_generaliza_solo_despues_de_experimentar() -> void:
	var body: BodyStub = BodyStub.new()
	var brain: FreeCatBrain = FreeCatBrain.new()
	brain.cat = body
	brain.curiosity = 0.0
	brain.travel_cost = 0.0
	brain.learning_rate = 1.0
	var unknown: Dictionary = brain.candidate("pez_2:bite:noche", "bite", Vector2.ZERO, "", "silver_long_shape")
	assert(is_zero_approx(float(unknown.score)))
	assert(unknown.evidence == "unknown")
	# Contrato de aprendizaje: datos corporales de un ensayo, no recompensa oculta.
	brain.choice = {"key": "pez_1:bite:dia", "model_key": "silver_long_shape:bite"}
	brain.baseline = body.needs.duplicate()
	brain.elapsed = 2.5
	brain.active = true
	body.needs.hunger = 55.0
	brain.finish_trial()
	body.needs.hunger = 10.0
	var transferred: Dictionary = brain.candidate("pez_2:bite:noche", "bite", Vector2.ZERO, "", "silver_long_shape")
	var other: Dictionary = brain.candidate("roca:bite:noche", "bite", Vector2.ZERO, "", "visible_rock")
	assert(float(transferred.score) > float(other.score))
	assert(transferred.evidence == "similar")
	assert(not brain.memory.has("pez_2:bite:noche"), "Transfiere sin inventar una experiencia local")
	var hungry_value: float = float(transferred.score)
	body.needs.hunger = 95.0
	var satiated: Dictionary = brain.candidate("pez_2:bite:noche", "bite", Vector2.ZERO, "", "silver_long_shape")
	assert(float(satiated.score) < hungry_value, "La utilidad aprendida depende de la necesidad presente")
	# La generalización también debe poder cambiar ante evidencia contraria.
	body.needs.hunger = 10.0
	brain.choice = {"key": "pez_2:bite:noche", "model_key": "silver_long_shape:bite"}
	brain.baseline = body.needs.duplicate()
	brain.elapsed = 2.5
	brain.active = true
	body.needs.hunger = 5.0
	brain.finish_trial()
	var revised: Dictionary = brain.candidate("pez_3:bite:noche", "bite", Vector2.ZERO, "", "silver_long_shape")
	assert(float(revised.score) < 0.0)
	brain.free()
	body.free()

func test_saturacion_no_borra_un_efecto_aprendido() -> void:
	var body: BodyStub = BodyStub.new()
	var brain: FreeCatBrain = FreeCatBrain.new()
	brain.cat = body
	brain.learning_rate = 1.0
	brain.models["forma:bite"] = {"n": 1, "effects": {"hunger": 7.0}}
	brain.choice = {"key": "otro:bite:dia", "model_key": "forma:bite"}
	body.needs.hunger = 100.0
	brain.baseline = body.needs.duplicate()
	brain.elapsed = 5.0
	brain.active = true
	brain.finish_trial()
	assert(is_equal_approx(float(brain.models["forma:bite"].effects.hunger), 7.0))
	assert(not brain.memory["otro:bite:dia"].effects.has("hunger"))
	brain.free()
	body.free()

func test_apariencia_no_revela_nutricion() -> void:
	var first: Fish = Fish.new()
	var second: Fish = Fish.new()
	first.nutrition = 45.0
	second.nutrition = 0.0
	assert(FreeCatBrain.appearance_key(first) == FreeCatBrain.appearance_key(second))
	first.free()
	second.free()

func test_saciedad_base_de_seis_minutos() -> void:
	var brain: FreeCatBrain = FreeCatBrain.new()
	assert(is_equal_approx(brain.satiety_decay_per_second() * 360.0, 100.0))
	brain.satiety_minutes = 12.0
	assert(is_equal_approx(brain.satiety_decay_per_second() * 360.0, 50.0))
	brain.free()

func test_curiosidad_decrece_con_repeticion_y_respeta_contexto() -> void:
	var body: BodyStub = BodyStub.new()
	body.needs.hunger = 50.0
	var brain: FreeCatBrain = FreeCatBrain.new()
	brain.cat = body
	brain.curiosity = 1.0
	brain.travel_cost = 0.0
	brain.memory["objeto:lie:dia"] = {"n": 24, "effects": {}}
	var familiar: Dictionary = brain.candidate("objeto:lie:dia", "lie", Vector2.ZERO, "")
	var unknown: Dictionary = brain.candidate("objeto:lie:noche", "lie", Vector2.ZERO, "")
	assert(float(unknown.score) > float(familiar.score))
	assert(is_equal_approx(float(familiar.score), 0.2))
	brain.free()
	body.free()

func test_sueno_umbral_histeresis_e_interrupcion() -> void:
	var body: BodyStub = BodyStub.new()
	var brain: FreeCatBrain = FreeCatBrain.new()
	brain.cat = body
	body.needs.hunger = 80.0
	body.needs.safety = 80.0
	body.needs.energy = 10.0
	assert(not brain.update_sleep_state())
	brain.active = true
	body.needs.energy = 9.9
	assert(brain.update_sleep_state())
	assert(not brain.active and brain.memory.is_empty())
	body.needs.energy = 84.9
	assert(brain.update_sleep_state())
	body.needs.hunger = 9.0
	assert(not brain.update_sleep_state())
	assert(brain.sleep_blocked)
	body.needs.energy = 1.0
	assert(not brain.update_sleep_state())
	body.needs.hunger = 20.0
	assert(brain.update_sleep_state())
	body.needs.energy = 85.0
	assert(not brain.update_sleep_state())
	brain.free()
	body.free()

func test_descanso_no_es_sueno_y_prioridad_es_aprendida() -> void:
	var body: BodyStub = BodyStub.new()
	var brain: FreeCatBrain = FreeCatBrain.new()
	brain.cat = body
	brain.travel_cost = 0.0
	body.needs.hunger = 50.0
	var novel_normal: float = float(brain.candidate("x", "bite", Vector2.ZERO, "").score)
	brain.memory["y"] = {"n": 1, "effects": {"hunger": 1.0}}
	var normal: float = float(brain.candidate("y", "paw", Vector2.ZERO, "").score)
	body.needs.hunger = 1.0
	var novel_critical: float = float(brain.candidate("x", "bite", Vector2.ZERO, "").score)
	var critical: float = float(brain.candidate("y", "paw", Vector2.ZERO, "").score)
	assert(novel_critical < novel_normal and critical > normal)
	assert(not FreeCatEffects.respond(null, "lie", 1.0, 1.0, false).has("energy"))
	brain.free()
	body.free()

func test_reporte_preserva_datos_y_estado() -> void:
	var body: BodyStub = BodyStub.new()
	var brain: FreeCatBrain = FreeCatBrain.new()
	brain.cat = body
	brain._loaded_report = {"dato_futuro": {"valor": 3}}
	brain.sleeping = true
	brain.sleep_blocked = true
	brain.memory = {"anterior": {"n": 1}}
	var saved: Dictionary = brain.report()
	assert(saved.dato_futuro.valor == 3 and saved.memory.has("anterior"))
	assert(saved.sleeping and saved.sleep_blocked and saved.needs == body.needs)
	brain.free()
	body.free()
