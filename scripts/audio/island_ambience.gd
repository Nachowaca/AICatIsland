class_name IslandAmbience
extends Node
## Una cama por capa. Sin timers/eventos por hora simulada ni cambios de pitch.
@export var sea: AudioStream = null
@export var wind: AudioStream = null
@export var night_insects: AudioStream = null
@export var day_night_path: NodePath = NodePath("../DayNight")
@export_range(0.1, 10.0) var fade_seconds: float = 2.5
var preferences: AudioPreferences = AudioPreferences.new()
var layer_muted: Array[bool] = [false, false, false]
var solo_layer: int = -1
var _players: Array[AudioStreamPlayer] = []
var _gains: Vector3 = Vector3.ZERO
var _last_usec: int = 0
var _cycle: DayNight
var _owns_audio: bool = false

func _ready() -> void:
	# Defensa ante dos instancias simultáneas de main; no añade un autoload.
	if get_tree().get_first_node_in_group("island_audio") != null:
		set_process(false)
		return
	add_to_group("island_audio")
	_owns_audio = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	preferences.load_preferences()
	preferences.apply()
	_cycle = get_node_or_null(day_night_path) as DayNight
	for layer_name: String in ["Sea", "Wind", "NightInsects"]:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = layer_name
		player.bus = &"Ambience"
		player.pitch_scale = 1.0
		player.max_polyphony = 1
		player.volume_linear = 0.0
		add_child(player)
		_players.append(player)
	refresh_streams()
	_last_usec = Time.get_ticks_usec()

## Tras asignar los exports desde código, llamar a refresh_streams().
## OGG/MP3 usan copia local en loop; WAV debe traer puntos de bucle/importación válidos.
func refresh_streams() -> void:
	if not _owns_audio:
		return
	var streams: Array[AudioStream] = [sea, wind, night_insects]
	for i: int in range(_players.size()):
		var player: AudioStreamPlayer = _players[i]
		player.stop()
		var source: AudioStream = streams[i]
		if source is AudioStreamOggVorbis:
			var ogg: AudioStreamOggVorbis = source.duplicate() as AudioStreamOggVorbis
			ogg.loop = true
			source = ogg
		elif source is AudioStreamMP3:
			var mp3: AudioStreamMP3 = source.duplicate() as AudioStreamMP3
			mp3.loop = true
			source = mp3
		elif source is AudioStreamWAV and (source as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
			push_warning("La cama WAV %s necesita bucle configurado al importar." % player.name)
		player.stream = source
		_gains[i] = 0.0
		player.volume_linear = 0.0
		if source != null:
			player.play()

static func layer_targets(night_factor: float) -> Vector3:
	var night: float = smoothstep(0.0, 1.0, clampf(night_factor, 0.0, 1.0))
	return Vector3(0.8, lerpf(0.55, 0.4, night), night * 0.65)

static func fade_gain(current: float, target: float, real_delta: float, seconds: float) -> float:
	return move_toward(current, target, maxf(real_delta, 0.0) / maxf(seconds, 0.001))

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var real_delta: float = float(now - _last_usec) / 1000000.0
	_last_usec = now
	var targets: Vector3 = layer_targets(_cycle.night_factor() if is_instance_valid(_cycle) else 0.0)
	for i: int in range(_players.size()):
		var target: float = targets[i]
		if layer_muted[i] or (solo_layer >= 0 and solo_layer != i):
			target = 0.0
		_gains[i] = fade_gain(_gains[i], target, real_delta, fade_seconds)
		_players[i].volume_linear = _gains[i]

func _exit_tree() -> void:
	if _owns_audio:
		# El aislamiento dev nunca se filtra al menú/siguiente escena.
		preferences.solo_bus = &""
		preferences.apply()
