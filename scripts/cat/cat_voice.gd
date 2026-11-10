class_name CatVoice
extends RefCounted
## Generador local. El llamador proporciona un RNG independiente del cerebro.
## Los eventos desconocidos devuelven "" y no consumen RNG.

const NOVEL_ACTION: String = "novel_action"
const DISCOVERY: String = "discovery"
const RESULT_POSITIVE: String = "result_positive"
const RESULT_NEGATIVE: String = "result_negative"
const NEED_HUNGER: String = "need_hunger"
const NEED_ENERGY: String = "need_energy"
const NEED_FUN: String = "need_fun"
const FUN_POSITIVE: String = "fun_positive"
const OBSERVE_DAY: String = "observe_day"
const OBSERVE_NIGHT: String = "observe_night"
const MEMORY: String = "memory"
const SLEEP: String = "sleep"
const WAKE: String = "wake"

const COOLDOWN_SECONDS: float = 4.0
const HISTORY_LIMIT: int = 8

var _last_time: float = -INF
var _last_priority: int = 0
var _recent: Array[String] = []

# Cada par contiene fragmentos intercambiables, no frases completas.
func _parts(event: String) -> Array:
	match event:
		NOVEL_ACTION:
			return [["¡Vaya,", "¡Oh,", "¡Anda,", "¡Mira,"], ["esto es nuevo!", "qué novedad!", "algo diferente!", "una nueva aventura!"]]
		DISCOVERY:
			return [["¡Oh,", "¡Vaya,", "¡Anda,", "¡Mira,"], ["qué descubrimiento!", "algo por descubrir!", "qué interesante!", "una sorpresa!"]]
		RESULT_POSITIVE:
			return [["¡Bien,", "¡Vaya,", "¡Mmm,", "¡Oh,"], ["me gusta!", "qué bien!", "eso sienta bien!", "qué buena sensación!"]]
		RESULT_NEGATIVE:
			return [["Ay,", "Uf,", "Mmm,", "Vaya,"], ["no me gusta.", "qué mal se siente.", "eso no sentó bien.", "prefiero otra cosa."]]
		NEED_HUNGER:
			return [["Mmm,", "Ay,", "Uf,", "Miau,"], ["tengo hambre.", "mi barriga pide algo.", "necesito comer.", "me ruge la barriga."]]
		NEED_ENERGY:
			return [["Uf,", "Mmm,", "Ay,", "Miau,"], ["necesito descansar.", "tengo sueño.", "me falta energía.", "quiero una pausa."]]
		NEED_FUN:
			return [["Mmm,", "Miau,", "Ay,", "Oh,"], ["quiero jugar.", "necesito diversión.", "me apetece jugar.", "quiero divertirme."]]
		FUN_POSITIVE:
			return [["¡Bien,", "¡Miau,", "¡Oh,", "¡Vaya,"], ["qué divertido!", "me divierto!", "me encanta jugar!", "qué entretenido!"]]
		OBSERVE_DAY:
			return [["Mmm,", "Miau,", "Oh,", "Vaya,"], ["es de día.", "un momento de día.", "otro rato de día.", "estamos de día."]]
		OBSERVE_NIGHT:
			return [["Mmm,", "Miau,", "Oh,", "Vaya,"], ["es de noche.", "un momento de noche.", "otro rato de noche.", "estamos de noche."]]
		MEMORY:
			return [["Mmm,", "Oh,", "Miau,", "Vaya,"], ["esto me hace pensar.", "me viene un recuerdo.", "algo me resulta familiar.", "creo recordar algo."]]
		SLEEP:
			return [["Mmm,", "Miau,", "Uf,", "Ay,"], ["a dormir.", "hora de descansar.", "cierro los ojos.", "a descansar."]]
		WAKE:
			return [["Mmm,", "Miau,", "Oh,", "Vaya,"], ["ya despierto.", "hora de despertar.", "abro los ojos.", "vuelvo a estar despierto."]]
	return []

func generate(event: String, rng: RandomNumberGenerator) -> String:
	var parts: Array = _parts(event)
	if parts.is_empty() or rng == null:
		return ""
	var beginnings: Array = parts[0]
	var endings: Array = parts[1]
	return str(beginnings[rng.randi_range(0, beginnings.size() - 1)], " ", endings[rng.randi_range(0, endings.size() - 1)])

## Durante el cooldown solo interrumpe una prioridad estrictamente mayor.
## Un rechazo no consume RNG ni modifica el historial; no hay cola interna.
## now_seconds debe ser monotónico y expresarse en segundos reales.
func speak(event: String, rng: RandomNumberGenerator, now_seconds: float, priority: int) -> String:
	var parts: Array = _parts(event)
	if parts.is_empty() or rng == null or not is_finite(now_seconds):
		return ""
	if now_seconds < _last_time:
		return ""
	if now_seconds - _last_time < COOLDOWN_SECONDS and priority <= _last_priority:
		return ""
	var beginnings: Array = parts[0]
	var endings: Array = parts[1]
	var count: int = beginnings.size() * endings.size()
	var start: int = rng.randi_range(0, count - 1)
	for offset: int in range(count):
		var index: int = (start + offset) % count
		var phrase: String = str(beginnings[floori(float(index) / float(endings.size()))], " ", endings[index % endings.size()])
		if not _recent.has(phrase):
			_recent.append(phrase)
			if _recent.size() > HISTORY_LIMIT:
				_recent.pop_front()
			_last_time = now_seconds
			_last_priority = priority
			return phrase
	return ""
