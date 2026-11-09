shader_type canvas_item;
// Agua procedural isométrica. Recibe un campo de distancia a la costa
// (en unidades de rejilla) y genera: color por profundidad, ondulación,
// cáusticas en lo poco profundo, olas que avanzan hacia la orilla,
// espuma en la rompiente, reflejo de la isla y destellos de sol/luna.

uniform sampler2D dist_tex : filter_linear, repeat_disable;
uniform float grid_span = 42.0;   // tamaño (en celdas) que cubre la textura
uniform float grid_pad = 8.0;     // celdas de margen antes de la celda 0
uniform float max_dist = 8.0;
uniform float night = 0.0;

uniform vec3 deep_col : source_color = vec3(0.05, 0.2, 0.38);
uniform vec3 mid_col : source_color = vec3(0.1, 0.38, 0.55);
uniform vec3 shallow_col : source_color = vec3(0.25, 0.66, 0.7);
uniform vec3 sand_col : source_color = vec3(0.62, 0.78, 0.66);
uniform vec3 foam_col : source_color = vec3(0.96, 0.98, 0.97);

varying vec2 lp;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
			   mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

vec2 to_grid(vec2 s) {
	float a = s.x / 32.0;
	float b = s.y / 16.0;
	return vec2((a + b) * 0.5, (b - a) * 0.5);
}

float dist_at(vec2 g) {
	return texture(dist_tex, (g + grid_pad) / grid_span).r * max_dist;
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float t = TIME;
	vec2 g = to_grid(lp);
	// espacio "desaplastado" para que los patrones respeten la perspectiva iso
	vec2 sp = lp * vec2(1.0, 2.0);

	float d = dist_at(g);
	vec2 warp = vec2(fbm(g * 0.6 + vec2(t * 0.05, 0.0)), fbm(g * 0.6 + vec2(3.1, -t * 0.04))) - 0.5;
	float dw = dist_at(g + warp * 0.6);

	// ---- color según profundidad
	vec3 col = mix(sand_col, shallow_col, smoothstep(0.0, 0.9, d));
	col = mix(col, mid_col, smoothstep(0.9, 3.2, dw));
	col = mix(col, deep_col, smoothstep(3.0, 7.5, dw));
	// manchas de fondo (algas/rocas) en lo poco profundo
	float bed = fbm(g * 1.3);
	col *= 1.0 - smoothstep(0.55, 0.75, bed) * 0.18 * (1.0 - smoothstep(0.5, 2.5, d));

	// ---- ondulación de la superficie
	float r1 = noise(sp * 0.03 + vec2(t * 0.22, t * 0.08));
	float r2 = noise(sp * 0.055 + vec2(-t * 0.18, t * 0.14) + 5.0);
	float ripple = r1 * 0.6 + r2 * 0.4;
	col += (ripple - 0.5) * 0.09;

	// ---- cáusticas (redes de luz) en el agua clara
	float ca = noise(sp * 0.07 + vec2(t * 0.35, t * 0.1));
	float cb = noise(sp * 0.07 * 1.37 + vec2(-t * 0.28, t * 0.2) + 11.0);
	float caustic = pow(clamp(1.0 - abs(ca - cb) * 3.5, 0.0, 1.0), 5.0);
	col += caustic * 0.22 * (1.0 - smoothstep(0.4, 2.8, d)) * (1.0 - night * 0.7);

	// ---- reflejo de la isla: lo que hay "encima" en pantalla se refleja abajo
	float wob = (noise(vec2(lp.y * 0.15, t * 1.2)) - 0.5) * 4.0;
	float land_above = 1.0 - smoothstep(0.0, 0.08, dist_at(to_grid(lp + vec2(wob, -9.0))));
	float land_above2 = 1.0 - smoothstep(0.0, 0.08, dist_at(to_grid(lp + vec2(wob * 1.5, -18.0))));
	float refl = max(land_above, land_above2 * 0.6) * step(0.02, d);
	col = mix(col, col * vec3(0.55, 0.7, 0.6), refl * 0.45);

	// ---- reflejo del cielo: vetas horizontales suaves
	float sky = noise(vec2(lp.x * 0.012 + t * 0.03, lp.y * 0.09 + t * 0.05));
	col += smoothstep(0.62, 0.92, sky) * 0.07 * smoothstep(1.0, 3.0, d);

	// ---- olas que avanzan hacia la costa y se rompen
	float phase = dw * 2.1 + t * 0.85;
	float crest = sin(phase);
	float wave = smoothstep(0.86, 0.99, crest);
	float wave_soft = smoothstep(0.4, 1.0, crest) * 0.06;
	float near_shore = (1.0 - smoothstep(0.9, 3.4, d)) * smoothstep(0.15, 0.55, d);
	float broken = smoothstep(0.35, 0.65, noise(sp * 0.06 + vec2(t * 0.15, 0.0)));
	col += wave_soft * (1.0 - smoothstep(2.0, 6.0, d));
	col = mix(col, foam_col, wave * near_shore * broken * 0.75);

	// ---- rompiente: espuma que sube y baja sobre la orilla
	float surge = 0.3 + 0.14 * sin(t * 1.1 + g.x * 0.55 + g.y * 0.4) + 0.06 * sin(t * 2.3 + g.x * 1.3);
	float edge_n = noise(sp * 0.11 + vec2(t * 0.4, -t * 0.2));
	float shore = 1.0 - smoothstep(surge * 0.55, surge + edge_n * 0.18, d);
	float bubbles = smoothstep(0.35, 0.7, noise(sp * 0.28 + vec2(t * 0.6, t * 0.3)));
	// línea de espuma que se queda atrás al retirarse el agua
	float trail = smoothstep(0.06, 0.0, abs(d - surge - 0.12)) * 0.5 * edge_n;
	col = mix(col, foam_col, clamp(shore * (0.55 + 0.45 * bubbles) + trail, 0.0, 1.0) * 0.9);

	// ---- destellos de sol (de noche, plateados de luna)
	vec2 gp = sp * 0.16;
	float s1 = noise(gp + vec2(t * 0.9, t * 0.3));
	float s2 = noise(gp * 1.31 + vec2(-t * 0.7, t * 0.5) + 17.0);
	// solo aparecen en "parches" grandes que se desplazan despacio
	float patch = smoothstep(0.55, 0.8, noise(sp * 0.004 + vec2(t * 0.03, -t * 0.02)));
	float glint = smoothstep(0.8, 0.92, s1 * s2 * 1.25) * patch * smoothstep(0.8, 2.0, d);
	vec3 glint_col = mix(vec3(1.0, 0.97, 0.85), vec3(0.75, 0.82, 1.0), night);
	col += glint * glint_col * mix(0.5, 0.3, night);

	COLOR = vec4(col, 1.0);
}
