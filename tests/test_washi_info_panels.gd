class_name TestWashiInfoPanels
extends Node


func test_fraccion_barra_clamp() -> void:
	assert(is_equal_approx(WashiInfoPanels.bar_fraction(50.0), 0.5))
	assert(is_equal_approx(WashiInfoPanels.bar_fraction(0.0), 0.0))
	assert(is_equal_approx(WashiInfoPanels.bar_fraction(100.0), 1.0))
	assert(is_equal_approx(WashiInfoPanels.bar_fraction(150.0), 1.0))
	assert(is_equal_approx(WashiInfoPanels.bar_fraction(-20.0), 0.0))
	assert(is_equal_approx(WashiInfoPanels.bar_fraction(0.3, 1.0), 0.3))
	assert(is_equal_approx(WashiInfoPanels.bar_fraction(10.0, 0.0), 0.0))
	assert(is_equal_approx(WashiInfoPanels.bar_fraction(NAN), 0.0))


func test_papel_noche_sigue_claro() -> void:
	var day_col: Color = WashiInfoPanels.paper_color(0.0)
	var night_col: Color = WashiInfoPanels.paper_color(1.0)
	assert(day_col.is_equal_approx(WashiInfoPanels.PAPER_DAY))
	assert(night_col.get_luminance() > 0.7)
	assert(night_col.get_luminance() - WashiInfoPanels.INK.get_luminance() > 0.5)


func test_paneles_sin_gato_no_fallan() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var panels: WashiInfoPanels = WashiInfoPanels.new()
	tree.root.add_child(panels)
	assert(panels.cat == null or is_instance_valid(panels.cat))
	panels.cat = null
	panels.day_night = null
	panels.refresh()
	panels._process(0.016)
	panels.set_night_factor(1.0)
	assert(is_equal_approx(panels.night, 1.0))
	panels.set_night_factor(-3.0)
	assert(is_zero_approx(panels.night))
	assert(panels.section_count() == 3)
	panels.set_all_sections_open(false)
	assert(not panels.any_section_open())
	panels.set_all_sections_open(true)
	assert(panels.any_section_open())
	assert(panels.panels_visible())
	panels.toggle_panels()
	assert(not panels.panels_visible())
	panels.toggle_panels()
	assert(panels.panels_visible())
	panels.free()
