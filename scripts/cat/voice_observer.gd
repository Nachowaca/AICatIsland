class_name VoiceObserver
extends RefCounted
## Capa expresiva aislada: nunca escribe en el selector ni usa su RNG.
const MAX_QUEUE = 64
var generator: CatVoice = CatVoice.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seen_actions: Dictionary = {}
var seen_discoveries: Dictionary = {}
var pending: Array[Dictionary] = []
var idle_at: float = 0.0
var active_priority: int = 0

func _init() -> void:
	rng.randomize()

func enqueue(event: String, priority: int) -> void:
	if event in [CatVoice.NEED_HUNGER, CatVoice.NEED_ENERGY, CatVoice.NEED_FUN, CatVoice.OBSERVE_DAY, CatVoice.OBSERVE_NIGHT, CatVoice.MEMORY]:
		for item: Dictionary in pending:
			if item.event == event:
				return
	if pending.size() >= MAX_QUEUE:
		pending.pop_front()
	pending.append({"event": event, "priority": priority})

func action_started(verb: String) -> void:
	if not seen_actions.has(verb):
		seen_actions[verb] = true
		enqueue(CatVoice.NOVEL_ACTION, 2)

func discovery(appearance: String) -> void:
	if appearance == "" or seen_discoveries.has(appearance):
		return
	seen_discoveries[appearance] = true
	enqueue(CatVoice.DISCOVERY, 3)

func result(changes: Dictionary) -> void:
	var total: float = 0.0
	for value: Variant in changes.values():
		total += float(value)
	if total > 1.0:
		enqueue(CatVoice.RESULT_POSITIVE, 2)
	elif total < -1.0:
		enqueue(CatVoice.RESULT_NEGATIVE, 3)

func periodic(needs: Dictionary, is_night: bool, has_memory: bool, now: float) -> void:
	if now < idle_at:
		return
	idle_at = now + rng.randf_range(12.0, 20.0)
	if float(needs.get("hunger", 100.0)) < 30.0:
		enqueue(CatVoice.NEED_HUNGER, 3)
	elif float(needs.get("energy", 100.0)) < 25.0:
		enqueue(CatVoice.NEED_ENERGY, 3)
	elif float(needs.get("fun", 100.0)) < 30.0:
		enqueue(CatVoice.NEED_FUN, 2)
	else:
		var options: Array[String] = [CatVoice.OBSERVE_NIGHT if is_night else CatVoice.OBSERVE_DAY]
		if has_memory:
			options.append(CatVoice.MEMORY)
		enqueue(options[rng.randi_range(0, options.size() - 1)], 1)

func next(now: float) -> String:
	if pending.is_empty():
		return ""
	var index: int = 0
	for i: int in range(1, pending.size()):
		if int(pending[i].priority) > int(pending[index].priority):
			index = i
	var item: Dictionary = pending[index]
	var text: String = generator.speak(String(item.event), rng, now, int(item.priority))
	if text != "":
		active_priority = int(item.priority)
		pending.remove_at(index)
	return text
