extends Node

const Voice = preload("res://scripts/cat/cat_voice.gd")
const EVENTS: Array[String] = ["novel_action", "discovery", "result_positive", "result_negative", "need_hunger", "need_energy", "need_fun", "fun_positive", "observe_day", "observe_night", "memory", "sleep", "wake"]

func test_variedad_longitud_y_eventos_desconocidos() -> void:
	var voice = Voice.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for event: String in EVENTS:
		var seen: Dictionary = {}
		for i: int in range(300):
			var text: String = voice.generate(event, rng)
			assert(not text.is_empty() and text.length() <= 65)
			seen[text] = true
		assert(seen.size() >= 12, "%s: solo %d" % [event, seen.size()])
	var state: int = rng.state
	assert(voice.generate("inexistente", rng) == "")
	assert(rng.state == state)
	assert(voice.generate("memory", null) == "")

func test_coherencia_de_fragmentos() -> void:
	var voice = Voice.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i: int in range(200):
		var hunger: String = voice.generate("need_hunger", rng).to_lower()
		assert(not "pescado" in hunger and not "comida aquí" in hunger)
		var memory: String = voice.generate("memory", rng).to_lower()
		assert(not "pescado" in memory and not "objeto" in memory)
		var day: String = voice.generate("observe_day", rng).to_lower()
		var night: String = voice.generate("observe_night", rng).to_lower()
		assert("día" in day and "noche" in night)
		var novel: String = voice.generate("novel_action", rng).to_lower()
		assert("nuevo" in novel or "novedad" in novel or "diferente" in novel or "nueva" in novel)

func test_cooldown_prioridad_historial_y_reloj() -> void:
	var voice = Voice.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 10
	var first: String = voice.speak("memory", rng, 10.0, 1)
	assert(not first.is_empty())
	var state: int = rng.state
	assert(voice.speak("memory", rng, 11.0, 1) == "")
	assert(voice.speak("memory", rng, 11.0, 0) == "")
	assert(voice.speak("unknown", rng, 11.0, 100) == "")
	assert(rng.state == state)
	var urgent: String = voice.speak("memory", rng, 11.0, 2)
	assert(not urgent.is_empty() and urgent != first)
	assert(voice.speak("memory", rng, 10.5, 99) == "")
	assert(voice.speak("memory", rng, 14.99, 2) == "")
	var recent: Array[String] = [first, urgent]
	for i: int in range(30):
		var phrase: String = voice.speak("memory", rng, 15.0 + 4.0 * i, 0)
		assert(not phrase.is_empty() and not recent.has(phrase))
		recent.append(phrase)
		if recent.size() > Voice.HISTORY_LIMIT:
			recent.pop_front()
