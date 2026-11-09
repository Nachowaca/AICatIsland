class_name AudioPreferences
extends RefCounted
## Preferencias independientes de la memoria del gato. Solo el aislamiento dev es temporal.
const DEFAULT_PATH: String = "user://audio_settings.cfg"
const BUSES: Array[StringName] = [&"Master", &"Music", &"Ambience", &"SFX"]
const DEFAULT_DB: Array[float] = [0.0, -22.0, -18.0, -12.0]
var volumes: Dictionary = {}
var muted: Dictionary = {}
var solo_bus: StringName = &""
var config_path: String = DEFAULT_PATH

func _init() -> void:
	for i: int in range(BUSES.size()):
		volumes[BUSES[i]] = DEFAULT_DB[i]
		muted[BUSES[i]] = false

static func ensure_buses() -> void:
	for bus_name: StringName in BUSES:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, String(bus_name))
		AudioServer.set_bus_send(index, &"Master")

func load_preferences() -> Error:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(config_path)
	if error != OK:
		return error
	for bus_name: StringName in BUSES:
		var level: Variant = config.get_value(String(bus_name), "volume_db", volumes[bus_name])
		if (level is float or level is int) and is_finite(float(level)):
			volumes[bus_name] = clampf(float(level), -60.0, 0.0)
		var silence: Variant = config.get_value(String(bus_name), "muted", false)
		if silence is bool:
			muted[bus_name] = silence
	return OK

func save_preferences() -> Error:
	var config: ConfigFile = ConfigFile.new()
	for bus_name: StringName in BUSES:
		config.set_value(String(bus_name), "volume_db", volumes[bus_name])
		config.set_value(String(bus_name), "muted", muted[bus_name])
	return config.save(config_path)

func set_volume_db(bus_name: StringName, value: float) -> void:
	if bus_name not in BUSES or not is_finite(value):
		return
	volumes[bus_name] = clampf(value, -60.0, 0.0)
	apply()
	_save_checked()

func set_muted(bus_name: StringName, value: bool) -> void:
	if bus_name not in BUSES:
		return
	muted[bus_name] = value
	apply()
	_save_checked()

func effective_mute(bus_name: StringName) -> bool:
	return bool(muted.get(bus_name, false)) or (bus_name != &"Master" and solo_bus != &"" and solo_bus != bus_name)

func apply() -> void:
	ensure_buses()
	for bus_name: StringName in BUSES:
		var index: int = AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_volume_db(index, float(volumes[bus_name]))
		AudioServer.set_bus_mute(index, effective_mute(bus_name))

func _save_checked() -> void:
	var error: Error = save_preferences()
	if error != OK:
		push_warning("No se pudieron guardar preferencias de audio: %s" % error_string(error))
