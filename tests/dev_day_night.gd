class_name DevDayNight
extends LightingPreview
## Prueba visual aislada: F6. No guarda el cerebro ni adelanta el contador de días.
@export_range(0.5, 15.0) var transition_seconds: float = 4.0

@onready var toggle: Button = $DevControls/Panel/Rows/Toggle
@onready var clock: Label = $DevControls/Panel/Rows/Clock
var cycle: DayNight
var _moving: bool = false
var _night: bool = false
var _elapsed: float = 0.0
var _from_hour: float = 12.0
var _to_hour: float = 21.0

func _ready() -> void:
	super._ready()
	cycle = get_node("Main/DayNight") as DayNight
	_night = cycle.is_night()
	toggle.pressed.connect(_toggle_time)
	_update_labels()

func _toggle_time() -> void:
	if _moving:
		return
	_from_hour = cycle.hour
	# Avanza por el atardecer o por medianoche y amanecer, nunca hacia atrás.
	_to_hour = 12.0 + 24.0 if _night else 21.0
	_elapsed = 0.0
	_moving = true
	toggle.disabled = true
	toggle.text = "Amaneciendo…" if _night else "Anocheciendo…"

func _process(delta: float) -> void:
	if cycle == null:
		return
	if _moving:
		_elapsed += delta / maxf(Engine.time_scale, 0.001)
		var progress: float = clampf(_elapsed / transition_seconds, 0.0, 1.0)
		cycle.hour = fposmod(lerpf(_from_hour, _to_hour, smoothstep(0.0, 1.0, progress)), 24.0)
		if progress >= 1.0:
			_moving = false
			_night = not _night
			toggle.disabled = false
	else:
		# Hora fija, pero siguen funcionando el mar, las velas y las animaciones.
		cycle.hour = 21.0 if _night else 12.0
	_update_labels()

func _update_labels() -> void:
	clock.text = "DEV · %s · %s" % [cycle.time_string(), cycle.phase_name()]
	if not _moving:
		toggle.text = "Pasar a día" if _night else "Pasar a noche"
