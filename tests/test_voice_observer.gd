class_name TestVoiceObserver
extends Node

func test_novedad_solo_una_vez_y_descubrimiento() -> void:
	var voice: VoiceObserver = VoiceObserver.new()
	voice.action_started("dig")
	voice.action_started("dig")
	voice.action_started("paw")
	voice.discovery("shell")
	voice.discovery("shell")
	assert(voice.pending.size() == 3)
	assert(voice.seen_actions.size() == 2)
	assert(voice.seen_discoveries.size() == 1)

func test_necesidad_periodica_y_recuerdo_con_evidencia() -> void:
	var voice: VoiceObserver = VoiceObserver.new()
	voice.periodic({"hunger": 5.0, "energy": 90.0, "fun": 80.0}, false, false, 0.0)
	assert(voice.pending.size() == 1)
	assert(voice.pending[0].event == CatVoice.NEED_HUNGER)
	voice.pending.clear()
	voice.idle_at = 0.0
	voice.periodic({"hunger": 90.0, "energy": 90.0, "fun": 80.0}, true, false, 100.0)
	assert(voice.pending[0].event == CatVoice.OBSERVE_NIGHT)

func test_cola_y_cooldown_no_pierden_novedades() -> void:
	var voice: VoiceObserver = VoiceObserver.new()
	voice.rng.seed = 21
	voice.action_started("dig")
	voice.action_started("paw")
	assert(voice.next(10.0) != "")
	assert(voice.next(11.0) == "")
	assert(voice.pending.size() == 1)
	assert(voice.next(15.0) != "")
	assert(voice.pending.is_empty())
