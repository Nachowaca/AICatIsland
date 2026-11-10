@tool
class_name FishSchools
extends Node2D
## Decoración independiente de Fish: coordenadas de rejilla relativas a Island.
## Puede asignarse island_path antes de entrar al árbol o llamarse set_island().

@export var island_path: NodePath = ^"../Island"
@export_range(0, 8) var school_count: int = 4

const CLEARANCE: float = 0.75
const SAMPLE_STEP: float = 0.1
const BODY_COLOR: Color = Color(0.09, 0.26, 0.30, 0.72)
const GLINT_COLOR: Color = Color(0.65, 0.83, 0.78, 0.52)

var _island: Island
var _schools: Array[Dictionary] = []
var _time: float = 0.0
var _retry: float = 0.0


## Comprueba también los extremos; distancia máxima entre muestras en celdas.
static func segment_is_water(a: Vector2, b: Vector2, sample: Callable, clearance: float = CLEARANCE) -> bool:
	if not sample.is_valid() or not a.is_finite() or not b.is_finite():
		return false
	var steps: int = maxi(1, ceili(a.distance_to(b) / SAMPLE_STEP))
	for i: int in range(steps + 1):
		var value: float = float(sample.call(a.lerp(b, float(i) / float(steps))))
		if not is_finite(value) or value >= -clearance:
			return false
	return true


func set_island(island: Island) -> void:
	if is_instance_valid(_island) and _island.regenerated.is_connected(_rebuild):
		_island.regenerated.disconnect(_rebuild)
	_island = island
	if is_instance_valid(_island) and not _island.regenerated.is_connected(_rebuild):
		_island.regenerated.connect(_rebuild)
	_rebuild()


func _ready() -> void:
	if not is_instance_valid(_island):
		_find_island()
	else:
		_rebuild()


func _find_island() -> void:
	var found: Island = get_node_or_null(island_path) as Island
	var ancestor: Node = get_parent()
	while found == null and ancestor != null:
		found = ancestor.get_node_or_null("Island") as Island
		ancestor = ancestor.get_parent()
	if found != null:
		set_island(found)


func _process(delta: float) -> void:
	if not is_instance_valid(_island):
		_schools.clear()
		_retry += delta
		if _retry >= 1.0:
			_retry = 0.0
			_find_island()
		queue_redraw()
		return
	if _island.field_n <= 1 or _island.coast_sdf.size() != _island.field_n * _island.field_n:
		_schools.clear()
		queue_redraw()
		return
	# También cubre un campo que todavía no existía al entrar al árbol.
	if _schools.is_empty():
		_retry += delta
		if _retry >= 2.0:
			_retry = 0.0
			_rebuild()
	_time += minf(delta, 0.1)
	if not _schools.is_empty():
		queue_redraw()


func _rebuild() -> void:
	_schools.clear()
	queue_redraw()
	if not is_instance_valid(_island) or _island.field_n <= 1 or _island.coast_sdf.size() != _island.field_n * _island.field_n:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _island.seed_value * 977 + 821
	var m: float = float(_island.map_size)
	for attempt: int in 400:
		if _schools.size() >= clampi(school_count, 0, 8):
			break
		var center: Vector2 = Vector2(rng.randf_range(0.5, m - 0.5), rng.randf_range(0.5, m - 0.5))
		# El radio reserva espacio para toda la órbita y los peces individuales.
		if _island.sdf_at(center) > -2.0:
			continue
		var separated: bool = true
		for school: Dictionary in _schools:
			if center.distance_to(school.center) < 3.0:
				separated = false
				break
		if not separated:
			continue
		var members: Array[Dictionary] = []
		for i: int in rng.randi_range(5, 8):
			members.append({"offset": Vector2(rng.randf_range(-0.33, 0.33), rng.randf_range(-0.33, 0.33)), "phase": rng.randf_range(0.0, TAU), "size": rng.randf_range(0.8, 1.15)})
		_schools.append({"center": center, "phase": rng.randf_range(0.0, TAU), "speed": rng.randf_range(0.24, 0.4), "members": members})


func _draw() -> void:
	if not is_instance_valid(_island) or _island.field_n <= 1 or _island.coast_sdf.size() != _island.field_n * _island.field_n:
		return
	for school: Dictionary in _schools:
		var phase: float = _time * float(school.speed) + float(school.phase)
		var orbit: Vector2 = Vector2(cos(phase), sin(phase)) * 0.35
		var tangent: Vector2 = Vector2(-sin(phase), cos(phase)).normalized()
		for member: Dictionary in school.members:
			var wobble: float = sin(_time * 3.0 + float(member.phase))
			var grid: Vector2 = (school.center as Vector2) + orbit + (member.offset as Vector2) + tangent.orthogonal() * wobble * 0.035
			# Suficiente margen para cuerpo, cola, sombra y su interpolación.
			if not segment_is_water(grid - tangent * 0.22, grid + tangent * 0.22, _island.sdf_at):
				continue
			var p: Vector2 = to_local(_island.to_global(Iso.to_screen(grid)))
			var screen_dir: Vector2 = (to_local(_island.to_global(Iso.to_screen(grid + tangent))) - p).normalized()
			if screen_dir.length_squared() < 0.01:
				continue
			_draw_fish(p, screen_dir, float(member.size), wobble)


func _draw_fish(p: Vector2, direction: Vector2, size: float, wobble: float) -> void:
	var side: Vector2 = direction.orthogonal()
	var head: Vector2 = p + direction * 5.2 * size
	var neck: Vector2 = p - direction * 3.0 * size
	var tail: Vector2 = p - direction * 5.7 * size + side * wobble * 0.7
	var body: PackedVector2Array = PackedVector2Array([head, p + direction * 1.0 * size + side * 2.0 * size, neck + side * 0.65 * size, tail + side * 1.8 * size, tail - side * 1.8 * size, neck - side * 0.65 * size, p + direction * 1.0 * size - side * 2.0 * size])
	draw_colored_polygon(body, BODY_COLOR)
	draw_line(p - direction * 1.5 * size, p + direction * 3.1 * size, GLINT_COLOR, 0.8)
