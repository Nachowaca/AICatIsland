class_name TestFishSchools
extends Node


func test_segmento_comprueba_interior_y_extremos() -> void:
	var coast: Callable = func(p: Vector2) -> float: return p.x - 1.0
	assert(FishSchools.segment_is_water(Vector2(0, 0), Vector2(0.2, 0), coast))
	assert(not FishSchools.segment_is_water(Vector2(0, 0), Vector2(0.4, 0), coast))
	var island_strip: Callable = func(p: Vector2) -> float: return 0.1 if absf(p.x - 0.5) < 0.06 else -2.0
	assert(not FishSchools.segment_is_water(Vector2.ZERO, Vector2.RIGHT, island_strip))


func test_segmento_rechaza_campos_invalidos() -> void:
	assert(not FishSchools.segment_is_water(Vector2.ZERO, Vector2.ONE, Callable()))
	var invalid: Callable = func(_p: Vector2) -> float: return NAN
	assert(not FishSchools.segment_is_water(Vector2.ZERO, Vector2.ZERO, invalid))


func test_proyeccion_isometrica_reversible() -> void:
	var p: Vector2 = Vector2(3.25, 7.75)
	assert(Iso.to_grid(Iso.to_screen(p)).is_equal_approx(p))
