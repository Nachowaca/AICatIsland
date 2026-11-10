class_name FreeCatEffects
extends RefCounted
## Leyes del cuerpo/objetos. El selector del cerebro nunca consulta esta tabla.

static func respond(target: Node2D, verb: String, dt: float, elapsed: float, night: bool) -> Dictionary:
	var effect: Dictionary = {}
	if verb == "lie":
		effect = {"comfort": 0.5} # Descanso despierto; la recuperación del sueño es aparte.
	elif verb == "groom":
		effect = {"comfort": 3.0, "fun": 0.5}
	if not is_instance_valid(target):
		return effect
	if target is Discoverable:
		var response: Dictionary = (target as Discoverable).respond(verb, dt, night)
		for key: String in response:
			if key == "_once":
				effect[key] = response[key]
			else:
				effect[key] = float(effect.get(key, 0.0)) + float(response[key])
	elif target is Fish and verb == "bite" and elapsed >= 2.5:
		effect["_once"] = {"hunger": (target as Fish).nutrition}
		target.queue_free()
	elif target is Interactable:
		var item: Interactable = target as Interactable
		if verb == "paw":
			if item.kind == Interactable.Kind.TEMARI:
				effect = {"fun": 9.0, "energy": -1.2}
				item.wiggle()
			elif item.kind == Interactable.Kind.SCRATCH_POST:
				effect = {"fun": 7.0, "energy": -0.8}
				item.wiggle()
	return effect
