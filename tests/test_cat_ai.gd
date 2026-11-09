extends Node
## Pruebas de la IA del gato: se carga la isla real, NO se le da ninguna orden
## y se simula el tiempo paso a paso. Solo se comprueba lo que el gato decide solo.

const DT = 0.1

var main: Node2D
var cat: Cat
var day_night: DayNight
var island: Island


func _setup() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node2D
	cat = main.get_node("Entities/Cat") as Cat
	cat.persist_brain = false # cerebro nuevo, no toca la partida guardada
	main.get_node("HUD").free()
	tree.root.add_child(main)
	day_night = main.get_node("DayNight") as DayNight
	island = main.get_node("Island") as Island


func _teardown() -> void:
	main.free()


## Avanza el mundo `seconds` segundos de juego. Devuelve el mínimo de cada necesidad.
func _sim(seconds: float) -> Dictionary:
	var mins: Dictionary = cat.needs.duplicate()
	var steps: int = int(seconds / DT)
	for i in steps:
		main._process(DT)
		day_night._process(DT)
		cat._process(DT)
		for f: Node in main.get_tree().get_nodes_in_group("fish"):
			if f.is_queued_for_deletion():
				f.remove_from_group("fish")
		for k: String in mins:
			mins[k] = minf(mins[k], cat.needs[k])
		if not island.is_walkable(cat.grid_pos):
			push_error("El gato salió de la isla en %s" % cat.grid_pos)
			break
	return mins


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ ", msg)
	else:
		push_error("✗ " + msg)


func _clear_fish() -> void:
	for f: Node in main.get_tree().get_nodes_in_group("fish"):
		f.remove_from_group("fish")
		f.queue_free()


# ------------------------------------------------------------------ pruebas

func test_sobrevive_solo_tres_dias() -> void:
	_setup()
	var start_day: int = day_night.day
	var mins: Dictionary = _sim(day_night.day_length_sec * 3.0)
	var used: Dictionary = {}
	for a: String in cat.learned:
		if absf(float(cat.learned[a]) - 1.0) > 0.001:
			used[a] = true
	print("  Días: %d | decisiones: %d | stats: %s" % [day_night.day - start_day, int(cat.stats.decisions), cat.stats])
	print("  Mínimos alcanzados: ", mins)
	print("  Personalidad final: ", cat.traits)
	print("  Diario:\n    " + "\n    ".join(cat.log_lines))
	_check(day_night.day - start_day >= 3, "pasaron 3 días sin intervención")
	_check(float(mins.hunger) > 5.0, "nunca llegó a morirse de hambre (mín %.0f)" % float(mins.hunger))
	_check(float(mins.energy) > 5.0, "nunca cayó agotado (mín %.0f)" % float(mins.energy))
	_check(int(cat.stats.fish_eaten) >= 3, "encontró y comió pescado solo (%d)" % int(cat.stats.fish_eaten))
	_check(int(cat.stats.decisions) >= 30, "tomó muchas decisiones propias (%d)" % int(cat.stats.decisions))
	_check(used.size() >= 4, "aprendió algo de al menos 4 acciones distintas (%d)" % used.size())
	print("  Descubrimientos: ", cat.knowledge.keys())
	_check(cat.knowledge.size() >= 4, "probó por su cuenta al menos 4 cosas+verbos desconocidos (%d)" % cat.knowledge.size())
	_teardown()


func test_descubre_solo_lo_enterrado() -> void:
	_setup()
	day_night.hour = 9.0
	var shell: Discoverable = main.get_node("Entities/BuriedShell") as Discoverable
	cat.grid_pos = shell.grid_pos + Vector2(0.6, 0.6)
	cat.traits.curiosity = 0.9
	cat.needs.merge({"hunger": 95.0, "energy": 95.0, "fun": 20.0, "safety": 100.0, "comfort": 95.0}, true)
	_clear_fish()
	_check(shell.perceived_kind() == "mound", "al principio solo ve un montículo")
	var bell: Discoverable = main.get_node("Entities/BuriedBell") as Discoverable
	var revealed: bool = false
	var t: float = 0.0
	while t < day_night.day_length_sec * 2.0:
		_sim(5.0)
		t += 5.0
		if not shell.buried or not bell.buried:
			revealed = true
			_sim(6.0) # que termine de escarbar y lo anote
			break
	_check(revealed, "sin que nadie se lo diga, escarba y desentierra algo (en %.0f s de juego)" % t)
	_check(cat.knowledge.has("mound:dig"), "aprendió que escarbar montículos tiene premio")
	if cat.knowledge.has("mound:dig"):
		_check(float(cat.knowledge["mound:dig"].eff.fun) > 1.0, "lo recuerda como divertido (%.1f/s)" % float(cat.knowledge["mound:dig"].eff.fun))
	_teardown()


func test_aprende_que_la_guarida_protege() -> void:
	_setup()
	day_night.hour = 22.0
	var hollow: Discoverable = main.get_node("Entities/RootHollow") as Discoverable
	cat.needs.merge({"hunger": 95.0, "energy": 95.0, "fun": 90.0, "safety": 60.0, "comfort": 95.0}, true)
	cat.grid_pos = hollow.interact_point()
	cat._int_verb = "lie"
	cat._int_key = "hollow:lie"
	cat._int_acc = {}
	cat._target = hollow
	cat.action = "interact"
	cat.phase = Cat.Phase.DOING
	cat._act_time = 0.0
	cat._act_duration = 6.0
	cat._needs_start = cat.needs.duplicate()
	_sim(7.0)
	_check(cat.knowledge.has("hollow:lie"), "registró la experiencia de tumbarse en la guarida")
	if cat.knowledge.has("hollow:lie"):
		_check(float(cat.knowledge["hollow:lie"].eff.safety) > 2.0, "aprendió que de noche la guarida da seguridad (%.1f/s)" % float(cat.knowledge["hollow:lie"].eff.safety))
	_teardown()


func test_con_hambre_va_a_por_el_pescado() -> void:
	_setup()
	day_night.hour = 10.0
	_clear_fish()
	var best_pair: Array = island.shore_pairs[0]
	for pair: Array in island.shore_pairs:
		if (pair[1] as Vector2).distance_to(cat.grid_pos) < (best_pair[1] as Vector2).distance_to(cat.grid_pos):
			best_pair = pair
	main.spawn_fish_at(best_pair)
	cat.needs.merge({"hunger": 15.0, "energy": 90.0, "fun": 90.0, "safety": 100.0, "comfort": 90.0}, true)
	cat._decide()
	_check(cat.action == "eat", "con hambre y pescado a la vista decide comer (eligió: %s)" % cat.action)
	_sim(20.0)
	_check(int(cat.stats.fish_eaten) == 1, "llegó hasta la orilla y se lo comió")
	_check(float(cat.needs.hunger) > 40.0, "su saciedad subió (%.0f)" % float(cat.needs.hunger))
	_check(cat.fish_memory.size() == 1, "memorizó el lugar donde encontró pescado")
	_teardown()


func test_de_noche_busca_proteccion() -> void:
	_setup()
	day_night.hour = 23.0
	cat.needs.merge({"hunger": 90.0, "energy": 25.0, "fun": 80.0, "safety": 20.0, "comfort": 90.0}, true)
	cat._decide()
	var target_name: String = String(cat._target.name) if cat._target else "—"
	_check(cat.action in ["sleep", "seek_light"], "de noche y asustado busca dormir o luz (eligió: %s)" % cat.action)
	_check(target_name == "Shrine" or target_name.begins_with("Lantern"), "va al santuario o a un farol (eligió: %s)" % target_name)
	_sim(30.0)
	_check(float(cat.needs.safety) > 50.0, "se siente seguro tras refugiarse (%.0f)" % float(cat.needs.safety))
	_teardown()


func test_con_calor_busca_sombra() -> void:
	_setup()
	day_night.hour = 13.5
	cat.needs.merge({"hunger": 90.0, "energy": 90.0, "fun": 90.0, "safety": 100.0, "comfort": 10.0}, true)
	cat._decide()
	_check(cat.action == "shade_rest", "al mediodía con calor elige descansar a la sombra (eligió: %s)" % cat.action)
	_sim(12.0)
	_check(cat._in_shade(), "está bajo un árbol")
	_check(float(cat.needs.comfort) > 10.0, "su confort se recupera (%.0f)" % float(cat.needs.comfort))
	_teardown()


func test_aburrido_juega() -> void:
	_setup()
	day_night.hour = 9.0
	_clear_fish()
	cat.needs.merge({"hunger": 95.0, "energy": 95.0, "fun": 5.0, "safety": 100.0, "comfort": 95.0}, true)
	cat._decide()
	_check(cat.action in ["play_post", "play_ball", "explore", "interact"], "aburrido busca diversión (eligió: %s)" % cat.action)
	_sim(15.0)
	_check(float(cat.needs.fun) > 25.0, "se divirtió (%.0f)" % float(cat.needs.fun))
	_teardown()
