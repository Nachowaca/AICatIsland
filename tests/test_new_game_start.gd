class_name TestNewGameStart
extends Node

func test_inicio_real_de_menu_pone_necesidades_al_cien_sin_guardar_memoria() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node2D
	var cat: Cat = main.get_node("Entities/Cat") as Cat
	cat.persist_brain = false
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("HUD").free()
	main.get_node("IslandAmbience").free()
	tree.root.set_meta(Cat.START_FULL_NEEDS_META, true)
	tree.root.add_child(main)
	assert(not tree.root.has_meta(Cat.START_FULL_NEEDS_META), "El arranque debe consumir el indicador de una sola vez")
	for need: String in cat.needs:
		assert(is_equal_approx(float(cat.needs[need]), 100.0), "%s debería empezar al 100" % need)
	assert(not cat.free_brain.sleeping)
	main.free()

func test_necesidades_nuevas_activas_al_cien() -> void:
	var cat: Cat = Cat.new()
	cat.needs = {"hunger": 23.0, "energy": 5.0, "fun": 0.0, "safety": 11.0, "comfort": 67.0}
	cat.set_needs_full()
	for need: String in cat.needs:
		assert(is_equal_approx(float(cat.needs[need]), 100.0), "%s debería iniciar llena" % need)
	cat.free()

func test_flag_de_inicio_es_de_una_partida_y_no_de_una_sesion() -> void:
	var root: Node = Node.new()
	root.set_meta(Cat.START_FULL_NEEDS_META, true)
	assert(root.has_meta(Cat.START_FULL_NEEDS_META))
	root.remove_meta(Cat.START_FULL_NEEDS_META)
	assert(not root.has_meta(Cat.START_FULL_NEEDS_META))
	root.free()

func test_inicio_no_cambia_memoria_aprendida() -> void:
	var cat: Cat = Cat.new()
	cat.knowledge["mound:dig"] = {"n": 3, "eff": {"fun": 6.0}}
	cat.set_needs_full()
	assert(cat.knowledge.has("mound:dig"))
	assert(int(cat.knowledge["mound:dig"].n) == 3)
	cat.free()
