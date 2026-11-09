class_name TestFreeCatBrain
extends Node
## Contratos del selector y medición; no sustituyen la observación en vivo.

class BodyStub:
	extends Node2D
	var needs: Dictionary = {"hunger": 10.0, "energy": 50.0, "fun": 50.0, "safety": 50.0, "comfort": 50.0}
	var grid_pos: Vector2 = Vector2.ZERO
	var persist_brain: bool = false
	func _log(_message: String) -> void:
		pass

func test_desgaste_base_equivale_a_diez_minutos() -> void:
	var brain: FreeCatBrain = FreeCatBrain.new()
	assert(is_equal_approx(brain.energy_decay_per_second() * 600.0, 100.0))
	brain.fatigue_minutes = 20.0
	assert(is_equal_approx(brain.energy_decay_per_second() * 600.0, 50.0))
	brain.fatigue_minutes = 0.0
	assert(brain.energy_decay_per_second() > 0.0)
	brain.free()

func test_no_nace_sabiendo_que_morder_alimenta() -> void:
	var body: BodyStub = BodyStub.new()
	var brain: FreeCatBrain = FreeCatBrain.new()
	brain.cat = body
	brain.curiosity = 0.0
	brain.travel_cost = 0.0
	var bite: Dictionary = brain.candidate("pescado:bite:dia", "bite", Vector2.ZERO, "")
	var sniff: Dictionary = brain.candidate("pescado:sniff:dia", "sniff", Vector2.ZERO, "")
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

func test_curiosidad_decrece_con_repeticion_y_respeta_contexto() -> void:
	var body: BodyStub = BodyStub.new()
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
