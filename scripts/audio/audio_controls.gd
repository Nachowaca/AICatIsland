class_name AudioControls
extends VBoxContainer
## Panel reutilizable. En el test dev incluye aislamientos temporales.
@export var controller_path: NodePath = NodePath("../../../..")
var controller: IslandAmbience
var developer_controls: bool = false

func _ready() -> void:
	if controller == null and not controller_path.is_empty():
		controller = get_node_or_null(controller_path) as IslandAmbience
	if controller == null:
		return
	var heading: Label = Label.new()
	var assigned: int = int(controller.sea != null) + int(controller.wind != null) + int(controller.night_insects != null)
	heading.text = "Audio · %d/3 capas asignadas" % assigned
	add_child(heading)
	for bus_name: StringName in AudioPreferences.BUSES:
		_add_bus_row(bus_name)
	if developer_controls:
		_add_dev_controls()

func _add_bus_row(bus_name: StringName) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	var label: Label = Label.new()
	label.text = {&"Master": "General", &"Music": "Música", &"Ambience": "Ambiente", &"SFX": "Efectos"}.get(bus_name, String(bus_name))
	label.custom_minimum_size = Vector2(85, 0)
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = -60.0
	slider.max_value = 0.0
	slider.step = 1.0
	slider.value = float(controller.preferences.volumes[bus_name])
	slider.custom_minimum_size = Vector2(130, 0)
	row.add_child(slider)
	var level: Label = Label.new()
	level.text = "%d dB" % slider.value
	row.add_child(level)
	slider.value_changed.connect(func(value: float) -> void:
		controller.preferences.set_volume_db(bus_name, value)
		level.text = "%d dB" % value
	)
	var mute: CheckButton = CheckButton.new()
	mute.text = "Mudo"
	mute.button_pressed = bool(controller.preferences.muted[bus_name])
	row.add_child(mute)
	mute.toggled.connect(func(value: bool) -> void: controller.preferences.set_muted(bus_name, value))

func _add_dev_controls() -> void:
	var bus_solo: OptionButton = OptionButton.new()
	for label: String in ["Buses: mezcla completa", "Solo música (pendiente)", "Solo ambiente", "Solo efectos (pendiente)"]:
		bus_solo.add_item(label)
	add_child(bus_solo)
	bus_solo.item_selected.connect(func(index: int) -> void:
		controller.preferences.solo_bus = &"" if index == 0 else AudioPreferences.BUSES[index]
		controller.preferences.apply()
	)
	var layer_solo: OptionButton = OptionButton.new()
	for label: String in ["Capas: mezcla completa", "Solo mar", "Solo brisa", "Solo grillos"]:
		layer_solo.add_item(label)
	add_child(layer_solo)
	layer_solo.item_selected.connect(func(index: int) -> void: controller.solo_layer = index - 1)
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	var names: Array[String] = ["Mar", "Brisa", "Grillos"]
	for i: int in range(3):
		var mute: CheckButton = CheckButton.new()
		mute.text = "Mudo " + names[i]
		row.add_child(mute)
		mute.toggled.connect(func(value: bool) -> void: controller.layer_muted[i] = value)
