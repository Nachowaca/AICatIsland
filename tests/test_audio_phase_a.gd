class_name TestAudioPhaseA
extends Node

func test_curvas_y_fundido_tiempo_real() -> void:
	var day: Vector3 = IslandAmbience.layer_targets(0.0)
	var night: Vector3 = IslandAmbience.layer_targets(1.0)
	assert(is_equal_approx(day.x, night.x))
	assert(is_zero_approx(day.z))
	assert(night.z > 0.0 and night.y < day.y)
	assert(IslandAmbience.layer_targets(-1.0) == day)
	assert(IslandAmbience.layer_targets(2.0) == night)
	var previous: Vector3 = day
	for i: int in range(1, 101):
		var current: Vector3 = IslandAmbience.layer_targets(float(i) / 100.0)
		assert(current.z >= previous.z)
		assert(current.distance_to(previous) < 0.02)
		previous = current
	var saved_scale: float = Engine.time_scale
	for scale: float in [1.0, 4.0, 10.0]:
		Engine.time_scale = scale
		assert(is_equal_approx(IslandAmbience.fade_gain(0.0, 1.0, 0.25, 2.5), 0.1))
	Engine.time_scale = saved_scale
	assert(is_equal_approx(IslandAmbience.fade_gain(0.2, 0.0, 100.0, 2.5), 0.0))

func test_buses_idempotentes_y_aislamiento() -> void:
	AudioPreferences.ensure_buses()
	var count: int = AudioServer.bus_count
	AudioPreferences.ensure_buses()
	assert(AudioServer.bus_count == count)
	var preferences: AudioPreferences = AudioPreferences.new()
	preferences.solo_bus = &"Ambience"
	assert(preferences.effective_mute(&"Music"))
	assert(preferences.effective_mute(&"SFX"))
	assert(not preferences.effective_mute(&"Ambience"))
	assert(not preferences.effective_mute(&"Master"))
	preferences.muted[&"Ambience"] = true
	assert(preferences.effective_mute(&"Ambience"))

func test_config_separado_roundtrip() -> void:
	var preferences: AudioPreferences = AudioPreferences.new()
	# Archivo de prueba separado: nunca toca audio_settings.cfg ni el cerebro.
	preferences.config_path = "user://audio_phase_a_test.cfg"
	preferences.volumes[&"Music"] = -31.0
	preferences.muted[&"Master"] = true
	preferences.solo_bus = &"Music"
	assert(preferences.save_preferences() == OK)
	var loaded: AudioPreferences = AudioPreferences.new()
	loaded.config_path = preferences.config_path
	assert(loaded.load_preferences() == OK)
	assert(is_equal_approx(float(loaded.volumes[&"Music"]), -31.0))
	assert(bool(loaded.muted[&"Master"]))
	assert(loaded.solo_bus == &"")

func test_controles_clamp_mute_y_bus_real() -> void:
	AudioPreferences.ensure_buses()
	var old_levels: Array[float] = []
	var old_mutes: Array[bool] = []
	for bus_name: StringName in AudioPreferences.BUSES:
		var index: int = AudioServer.get_bus_index(bus_name)
		old_levels.append(AudioServer.get_bus_volume_db(index))
		old_mutes.append(AudioServer.is_bus_mute(index))
	var preferences: AudioPreferences = AudioPreferences.new()
	preferences.config_path = "user://audio_phase_a_test.cfg"
	preferences.set_volume_db(&"Music", 12.0)
	assert(is_zero_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music"))))
	preferences.set_volume_db(&"SFX", -100.0)
	assert(is_equal_approx(float(preferences.volumes[&"SFX"]), -60.0))
	preferences.set_muted(&"Ambience", true)
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Ambience")))
	assert(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")))
	preferences.set_muted(&"Master", true)
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")))
	for i: int in range(AudioPreferences.BUSES.size()):
		var index: int = AudioServer.get_bus_index(AudioPreferences.BUSES[i])
		AudioServer.set_bus_volume_db(index, old_levels[i])
		AudioServer.set_bus_mute(index, old_mutes[i])

func test_escena_con_tres_ambientes_asignados() -> void:
	var packed: PackedScene = load("res://scenes/audio/island_ambience.tscn") as PackedScene
	var audio: IslandAmbience = packed.instantiate() as IslandAmbience
	for stream: AudioStream in [audio.sea, audio.wind, audio.night_insects]:
		assert(stream != null)
		assert(stream.get_length() >= 10.0)
	audio.free()

func test_slots_vacios_y_un_solo_controlador_en_main() -> void:
	var audio: IslandAmbience = IslandAmbience.new()
	assert(audio.sea == null and audio.wind == null and audio.night_insects == null)
	audio.free()
	# Solo lectura de archivos: no instancia main ni ejecuta fullscreen/cerebro.
	var main_text: String = FileAccess.get_file_as_string("res://scenes/main.tscn")
	assert(main_text.count('[node name="IslandAmbience"') == 1)
	assert(main_text.count('res://scenes/audio/island_ambience.tscn') == 1)
