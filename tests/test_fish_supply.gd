class_name TestFishSupply
extends Node
## Contratos del suministro: sin arrancar ni simular decisiones del gato.

func _world(initial: int = 8, limit: int = 12, keep_scene_fish: bool = true) -> Node2D:
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node2D
	main.initial_fish = initial
	main.max_fish = limit
	main.spawn_interval = 8.0
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var cat: Cat = main.get_node("Entities/Cat") as Cat
	cat.persist_brain = false
	cat.process_mode = Node.PROCESS_MODE_DISABLED
	# Desactivar _process no impide _ready: se retira antes de entrar al árbol
	# para que tampoco decida ni inicialice el cerebro durante estas pruebas.
	cat.free()
	main.get_node("HUD").free()
	main.get_node("IslandAmbience").free()
	if not keep_scene_fish:
		main.get_node("Entities/Fish").free()
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main._follow = false
	return main


func _check_coast(main: Node2D) -> void:
	var fish: Array[Fish] = main._live_fish()
	var island: Island = main.get_node("Island") as Island
	for i: int in fish.size():
		assert(island.is_walkable(fish[i].land_spot), "El punto para comer debe ser tierra válida")
		var matched: bool = false
		for pair: Array in island.shore_pairs:
			var spots: Array = island.shore_spots(pair)
			if fish[i].grid_pos.is_equal_approx(spots[0]) and fish[i].land_spot.is_equal_approx(spots[0]):
				matched = true
				break
		assert(matched, "Cada pescado procede de shore_spots de la costa real")
		for j: int in range(i + 1, fish.size()):
			assert(fish[i].grid_pos.distance_to(fish[j].grid_pos) >= 1.3, "Separación mínima de 1.3 celdas")


func test_exports_y_poblacion_inicial() -> void:
	var defaults: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node2D
	assert(defaults.max_fish == 5)
	assert(defaults.initial_fish == 1)
	assert(is_equal_approx(defaults.spawn_interval, 35.0))
	(defaults.get_node("Entities/Cat") as Cat).persist_brain = false
	defaults.free()
	var main: Node2D = _world()
	assert(main._live_fish().size() == 8, "Los peces de escena cuentan en el objetivo inicial")
	_check_coast(main)
	main.free()


func test_objetivo_limitado_y_suministro_cero() -> void:
	var main: Node2D = _world(30, 4)
	assert(main._live_fish().size() == 4)
	_check_coast(main)
	main.free()
	main = _world(0, 3)
	assert(main._live_fish().size() == 1, "initial_fish=0 conserva el suministro original de escena")
	main.free()
	main = _world(8, 0)
	assert(main._live_fish().is_empty())
	main._process(100.0)
	assert(main._live_fish().is_empty())
	main.free()


func test_reposicion_periodica_y_tope_de_clics() -> void:
	var main: Node2D = _world(0, 3, false)
	(main.get_node("DayNight") as DayNight).hour = 12.0
	main._process(7.9)
	assert(main._live_fish().is_empty())
	main._process(0.2)
	assert(main._live_fish().size() == 1)
	main._process(8.0)
	assert(main._live_fish().size() == 2)
	main._process(8.0)
	assert(main._live_fish().size() == 3)
	var island: Island = main.get_node("Island") as Island
	for pair: Array in island.shore_pairs:
		assert(not main.spawn_fish_at(pair), "Incluso el spawn manual respeta max_fish")
		main._drop_fish_near(pair[0])
	assert(main._live_fish().size() == 3)
	main._process(80.0)
	assert(main._live_fish().size() == 3)
	_check_coast(main)
	main.free()


func test_queued_no_ocupa_cupo_ni_posicion() -> void:
	var main: Node2D = _world(0, 1, false)
	var island: Island = main.get_node("Island") as Island
	var selected: Array = []
	for pair: Array in island.shore_pairs:
		if main.spawn_fish_at(pair):
			selected = pair
			break
	assert(not selected.is_empty())
	var eaten: Fish = main._live_fish()[0]
	eaten.queue_free()
	assert(eaten.is_in_group("fish"), "La prueba no retira manualmente del grupo")
	assert(main.spawn_fish_at(selected), "Un pez pendiente de borrar no ocupa cupo ni espacio")
	assert(main._live_fish().size() == 1)
	main._live_fish()[0].queue_free()
	(main.get_node("DayNight") as DayNight).hour = 12.0
	main._process(8.0)
	assert(main._live_fish().size() == 1, "La reposición también ignora queued_for_deletion")
	_check_coast(main)
	main.free()


func test_spawn_rechaza_duplicados_y_pares_ajenos() -> void:
	var main: Node2D = _world(0, 12, false)
	assert(not main.spawn_fish_at([]))
	assert(not main.spawn_fish_at([Vector2.ZERO, Vector2.ONE]))
	var island: Island = main.get_node("Island") as Island
	for pair: Array in island.shore_pairs:
		if main.spawn_fish_at(pair):
			assert(not main.spawn_fish_at(pair), "No se apilan peces en el mismo lugar")
	assert(main._live_fish().size() == 12)
	_check_coast(main)
	main.free()


func test_costa_vacia_y_saturada_sin_bucles() -> void:
	var main: Node2D = _world(0, 12, false)
	var island: Island = main.get_node("Island") as Island
	var valid_pair: Array = []
	for pair: Array in island.shore_pairs:
		if island.is_walkable(island.shore_spots(pair)[0]):
			valid_pair = pair
			break
	assert(not valid_pair.is_empty())
	island.shore_pairs = [valid_pair]
	main._supply_fish(12)
	assert(main._live_fish().size() == 1)
	main._supply_fish(12)
	assert(main._live_fish().size() == 1, "Costa saturada: termina sin apilar")
	island.shore_pairs = []
	main._supply_fish(12)
	main._process(80.0)
	assert(main._live_fish().size() == 1, "Costa vacía: no indexa ni entra en bucle")
	main.free()
