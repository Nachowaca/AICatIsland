shader_type canvas_item;
// Mar + playa procedurales en vista isométrica.
// field_tex.r = distancia con signo a la costa en celdas (+ tierra, − agua)
// field_tex.g = máscara de pasto (para la sombra del talud y los reflejos)
// La arena es plana, a nivel del mar: el agua sube y baja sobre ella.

uniform sampler2D field_tex : filter_linear, repeat_disable;
uniform float grid_span = 42.0;
uniform float grid_pad = 8.0;
uniform float night = 0.0;

uniform vec3 deep_col : source_color = vec3(0.05, 0.2, 0.38);
uniform vec3 mid_col : source_color = vec3(0.1, 0.38, 0.55);
uniform vec3 shallow_col : source_color = vec3(0.22, 0.64, 0.68);
uniform vec3 lagoon_col : source_color = vec3(0.45, 0.8, 0.74);
uniform vec3 foam_col : source_color = vec3(0.97, 0.98, 0.97);
uniform vec3 sand_dry : source_color = vec3(0.96, 0.88, 0.7);
uniform vec3 sand_dark : source_color = vec3(0.86, 0.75, 0.55);
uniform vec3 sand_wet : source_color = vec3(0.7, 0.6, 0.44);

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

vec2 field(vec2 g) {
	return texture(field_tex, (g + grid_pad) / grid_span).rg;
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float t = TIME;
	vec2 g = to_grid(lp);
	vec2 sp = lp * vec2(1.0, 2.0);   // espacio "desaplastado" para patrones iso

	vec2 f = field(g);
	float sdf = f.r;                  // + tierra, − agua
	float d = max(-sdf, 0.0);         // profundidad aproximada
	vec2 warp = vec2(fbm(g * 0.6 + vec2(t * 0.05, 0.0)), fbm(g * 0.6 + vec2(3.1, -t * 0.04))) - 0.5;
	float dw = max(-field(g + warp * 0.6).r, 0.0);

	// ================= ritmo de las olas (sincronizado con las crestas)
	float phase = dw * 2.1 + t * 0.85;
	float local = warp.x * 1.3;
	float wave_count = (t * 0.85 - 1.5708 + local) / 6.2832;
	float cyc = fract(wave_count);
	// sube rápido, se retira despacio
	float run = cyc < 0.22 ? smoothstep(0.0, 0.22, cyc) : 1.0 - smoothstep(0.22, 0.95, cyc);
	// cada ola llega distinto de lejos (unas más grandes que otras)
	float reach_mod = 0.6 + 0.65 * noise(g * 0.9 + vec2(floor(wave_count) * 3.7, 0.0));
	float reach = mix(-0.12, 0.62, run) * reach_mod;    // hasta dónde sube el agua (celdas)

	// ================= AGUA
	vec3 water = mix(lagoon_col, shallow_col, smoothstep(0.0, 1.0, dw));
	water = mix(water, mid_col, smoothstep(0.9, 3.2, dw));
	water = mix(water, deep_col, smoothstep(3.0, 7.5, dw));
	// fondo de arena que se transparenta en la orilla
	water = mix(sand_wet * 0.95 + vec3(0.0, 0.08, 0.08), water, smoothstep(0.0, 0.7, d));
	float bed = fbm(g * 1.3);
	water *= 1.0 - smoothstep(0.55, 0.75, bed) * 0.16 * (1.0 - smoothstep(0.5, 2.5, d));
	float r1 = noise(sp * 0.03 + vec2(t * 0.22, t * 0.08));
	float r2 = noise(sp * 0.055 + vec2(-t * 0.18, t * 0.14) + 5.0);
	water += ((r1 * 0.6 + r2 * 0.4) - 0.5) * 0.09;
	float ca = noise(sp * 0.07 + vec2(t * 0.35, t * 0.1));
	float cb = noise(sp * 0.07 * 1.37 + vec2(-t * 0.28, t * 0.2) + 11.0);
	float caustic = pow(clamp(1.0 - abs(ca - cb) * 3.5, 0.0, 1.0), 5.0);
	water += caustic * 0.22 * (1.0 - smoothstep(0.3, 2.8, d)) * (1.0 - night * 0.7);
	// reflejo del talud de pasto
	float wob = (noise(vec2(lp.y * 0.15, t * 1.2)) - 0.5) * 4.0;
	float refl = max(field(to_grid(lp + vec2(wob, -9.0))).g, field(to_grid(lp + vec2(wob * 1.5, -18.0))).g * 0.6);
	water = mix(water, water * vec3(0.55, 0.72, 0.6), refl * 0.45);
	float sky = noise(vec2(lp.x * 0.012 + t * 0.03, lp.y * 0.09 + t * 0.05));
	water += smoothstep(0.62, 0.92, sky) * 0.07 * smoothstep(1.0, 3.0, d);
	// crestas que avanzan hacia la playa y se rompen
	float crest = sin(phase);
	float wave = smoothstep(0.86, 0.99, crest);
	float near_shore = (1.0 - smoothstep(0.9, 3.6, d)) * smoothstep(0.25, 0.7, d);
	float broken = smoothstep(0.35, 0.65, noise(sp * 0.06 + vec2(t * 0.15, 0.0)));
	water += smoothstep(0.4, 1.0, crest) * 0.06 * (1.0 - smoothstep(2.0, 6.0, d));
	water = mix(water, foam_col, wave * near_shore * broken * 0.75);
	// destellos
	float s1 = noise(sp * 0.16 + vec2(t * 0.9, t * 0.3));
	float s2 = noise(sp * 0.16 * 1.31 + vec2(-t * 0.7, t * 0.5) + 17.0);
	float patch = smoothstep(0.55, 0.8, noise(sp * 0.004 + vec2(t * 0.03, -t * 0.02)));
	float glint = smoothstep(0.8, 0.92, s1 * s2 * 1.25) * patch * smoothstep(0.8, 2.0, d);
	water += glint * mix(vec3(1.0, 0.97, 0.85), vec3(0.75, 0.82, 1.0), night) * mix(0.5, 0.3, night);

	// ================= ARENA
	float grain = noise(sp * 0.5) * 0.5 + noise(sp * 1.3) * 0.5;
	vec3 sand = mix(sand_dark, sand_dry, smoothstep(0.2, 1.4, sdf));
	sand *= 0.96 + grain * 0.08;
	// ondas de viento en la arena seca
	float ripple = sin(dot(g, vec2(3.1, 1.4)) * 4.0 + fbm(g * 1.5) * 6.0);
	sand *= 1.0 - smoothstep(0.6, 1.0, ripple) * 0.05 * smoothstep(0.7, 1.4, sdf);
	// guijarros y conchitas
	vec2 cellp = floor(sp * 0.33);
	float hpeb = hash(cellp);
	vec2 inp = fract(sp * 0.33) - 0.5;
	float dot_r = length(inp * vec2(1.0, 1.6));
	if (hpeb > 0.975 && dot_r < 0.28) {
		sand = mix(sand, vec3(0.55, 0.52, 0.5), 0.8);
	} else if (hpeb < 0.012 && dot_r < 0.22) {
		sand = mix(sand, vec3(1.0, 0.86, 0.82), 0.9);
	}
	// banda mojada (con brillo de cielo) donde llega el agua
	float wet_line = 0.75 + 0.15 * noise(g * 1.2);
	float wet = 1.0 - smoothstep(max(reach, 0.0), wet_line, sdf);
	wet = max(wet, (1.0 - smoothstep(0.0, wet_line, sdf)) * 0.75);
	sand = mix(sand, sand_wet, wet * 0.8);
	sand += wet * smoothstep(0.5, 0.9, noise(vec2(lp.x * 0.02, lp.y * 0.12) + t * 0.05)) * 0.08;
	// sombra del talud de pasto (la luz viene de arriba a la izquierda)
	float bluff = field(g - vec2(0.22, 0.22)).g * (1.0 - f.g);
	sand *= 1.0 - bluff * 0.28;

	// ================= COMPOSICIÓN
	vec3 col = sdf > 0.0 ? sand : water;
	// lámina de agua que sube por la playa
	float film = (1.0 - smoothstep(reach - 0.04, reach + 0.02, sdf)) * step(0.0, sdf);
	vec3 film_col = mix(sand_wet, lagoon_col, 0.55) + caustic * 0.12;
	col = mix(col, film_col, film * 0.7);
	// espuma en el frente de la ola (borde irregular con burbujas)
	float edge_n = noise(sp * 0.11 + vec2(t * 0.4, -t * 0.2));
	float front = 1.0 - smoothstep(0.0, 0.07 + edge_n * 0.07, abs(sdf - reach));
	float bn = noise(sp * 0.28 + vec2(t * 0.6, t * 0.3)) * 0.65 + noise(sp * 0.6 - vec2(t * 0.4, 0.0)) * 0.35;
	float bubbles = smoothstep(0.52, 0.62, bn);   // burbujas nítidas, no manchas
	float churn = (1.0 - smoothstep(0.05, 0.4, abs(sdf - reach + 0.18))) * bubbles;
	float foam = clamp(front + churn * 0.85, 0.0, 1.0);
	foam *= smoothstep(-0.9, -0.3, sdf);  // solo cerca de la orilla
	// encaje de espuma que queda sobre la arena mientras el agua se retira
	float lace_pos = 0.62 * reach_mod * 0.92;
	float lace = (1.0 - smoothstep(0.0, 0.035, abs(sdf - lace_pos)));
	lace *= smoothstep(0.25, 0.45, cyc) * (1.0 - smoothstep(0.6, 0.9, cyc));
	lace *= smoothstep(0.4, 0.7, noise(sp * 0.2));
	col = mix(col, foam_col, max(foam, lace * 0.7));

	COLOR = vec4(col, 1.0);
}
