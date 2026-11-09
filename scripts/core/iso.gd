class_name Iso
extends RefCounted
## Conversión entre coordenadas de rejilla isométrica y pantalla.

const TILE_W = 64.0
const TILE_H = 32.0


static func to_screen(g: Vector2) -> Vector2:
	return Vector2((g.x - g.y) * TILE_W * 0.5, (g.x + g.y) * TILE_H * 0.5)


static func to_grid(s: Vector2) -> Vector2:
	var a: float = s.x / (TILE_W * 0.5)
	var b: float = s.y / (TILE_H * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)
