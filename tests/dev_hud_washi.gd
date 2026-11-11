class_name DevHudWashi
extends Node
## Prueba visual aislada (F6) de los paneles washi. No guarda el cerebro del gato.

var main: Node2D
var cycle: DayNight
var panels: WashiInfoPanels
var _night: bool = false
var _toggle: Button
var _fold: Button


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node2D
	(main.get_node("Entities/Cat") as Cat).persist_brain = false
	add_child(main)
	(main.get_node("HUD") as CanvasLayer).visible = false
	var audio_ui: CanvasLayer = main.get_node_or_null("IslandAmbience/Interface") as CanvasLayer
	if audio_ui != null:
		audio_ui.visible = false
	cycle = main.get_node_or_null("DayNight") as DayNight
	panels = WashiInfoPanels.new()
	panels.name = "WashiInfoPanels"
	add_child(panels)
	_build_dev_controls()


func _build_dev_controls() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "DevControls"
	layer.layer = 100
	add_child(layer)
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	layer.add_child(box)
	_toggle = Button.new()
	_toggle.text = "Día / Noche"
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.add_theme_font_size_override("font_size", 11)
	_toggle.pressed.connect(_toggle_time)
	box.add_child(_toggle)
	_fold = Button.new()
	_fold.text = "Plegar todo"
	_fold.focus_mode = Control.FOCUS_NONE
	_fold.add_theme_font_size_override("font_size", 11)
	_fold.pressed.connect(_toggle_fold)
	box.add_child(_fold)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 8)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _toggle_time() -> void:
	_night = not _night


func _toggle_fold() -> void:
	var open: bool = not panels.any_section_open()
	panels.set_all_sections_open(open)
	_fold.text = "Plegar todo" if open else "Desplegar todo"


func _process(_delta: float) -> void:
	if cycle == null:
		return
	# Hora fija mientras se inspecciona; mar, velas y gato siguen animándose.
	cycle.hour = 21.0 if _night else 12.0
	_toggle.text = "Día / Noche · %s" % ("Noche" if _night else "Día")
