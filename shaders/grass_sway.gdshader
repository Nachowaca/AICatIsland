shader_type canvas_item;
// Mece el pasto con el viento sin redibujar nada desde GDScript.
// Las puntas de las briznas llegan con COLOR.a ligeramente menor que 1:
//   a = 1.0 - 0.02 * flex   (flex 0 = raíz fija, 1 = punta libre)
// El shader recupera "flex", desplaza el vértice y devuelve alfa = 1.

uniform float strength = 2.2;
uniform float gust_strength = 2.5;

void vertex() {
	// solo los alfas en [0.979, 1] son código de flexión; el resto (sombras) se respeta
	if (COLOR.a >= 0.979) {
		float flex = clamp((1.0 - COLOR.a) / 0.02, 0.0, 1.0);
		vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
		float breeze = sin(TIME * 1.4 + wp.x * 0.025 - wp.y * 0.015) * 0.6
			+ sin(TIME * 2.9 + wp.x * 0.09 + wp.y * 0.04) * 0.25;
		// ráfaga que barre la isla de izquierda a derecha cada pocos segundos
		float gust = smoothstep(0.55, 1.0, sin(TIME * 0.45 - wp.x * 0.006 + wp.y * 0.002));
		float sway = breeze * strength + gust * gust_strength;
		VERTEX.x += sway * flex * flex;
		VERTEX.y += abs(sway) * flex * flex * 0.25;
		COLOR.a = 1.0;
	}
}
