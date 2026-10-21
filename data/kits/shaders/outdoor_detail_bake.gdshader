shader_type canvas_item;
// Bakea el detalle de las caras de arriba de epiphany_outdoor.gdshader (losas, piedritas, matitas) a dos texturas que se
// repiten cada PERIOD metros, para la variante Mobile. Mismas cuentas, con las celdas envueltas para que la textura
// empalme; las frecuencias van redondeadas a un número entero de celdas por período.
//   a: r = manchas, g = distancia al borde de la losa / EDGE_RANGE, b = tono de la losa, a = tierra de la losa (hash en octavos)
//   b: r = factor de la tierra / 1.5, g = factor del pasto / 1.5, b = matitas
render_mode blend_disabled;

uniform int layer = 0;

const float PERIOD = 28.0;
const float EDGE_RANGE = 0.2;
const float STONE_CELLS = 25.0;
const float PEBBLE_CELLS = 80.0;
const float TUFT_CELLS = 40.0;

vec2 wrap(vec2 c, float n) {
	return mod(c, n);
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

float value_noise(vec2 p, float n) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash1(wrap(i, n)), hash1(wrap(i + vec2(1.0, 0.0), n)), f.x),
			mix(hash1(wrap(i + vec2(0.0, 1.0), n)), hash1(wrap(i + vec2(1.0, 1.0), n)), f.x), f.y);
}

vec3 stones(vec2 p, float jitter, float n_cells) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	vec2 best_cell = vec2(0.0);
	vec2 best_r = vec2(0.0);
	float d1 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + 0.5 + (hash2(wrap(n + g, n_cells)) - 0.5) * 2.0 * jitter - f;
			float d = dot(r, r);
			if (d < d1) {
				d1 = d;
				best_r = r;
				best_cell = wrap(n + g, n_cells);
			}
		}
	}
	float edge = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + 0.5 + (hash2(wrap(n + g, n_cells)) - 0.5) * 2.0 * jitter - f;
			vec2 diff = r - best_r;
			if (dot(diff, diff) > 0.0001) {
				edge = min(edge, dot(0.5 * (best_r + r), normalize(diff)));
			}
		}
	}
	return vec3(edge, best_cell);
}

void fragment() {
	vec2 p = UV * PERIOD;
	float spots = value_noise(p * 10.0 / PERIOD, 10.0) * 0.55 + value_noise(p * 53.0 / PERIOD, 53.0) * 0.3
			+ value_noise(p * 196.0 / PERIOD, 196.0) * 0.15;
	if (layer == 0) {
		float size = PERIOD / STONE_CELLS;
		vec3 s = stones(p / size, 0.38, STONE_CELLS);
		// La tierra va en octavos centrados: la compresión de la textura no la cruza de lado contra floor_earth.
		float earth = (floor(hash1(s.yz + 11.0) * 8.0) + 0.5) / 8.0;
		COLOR = vec4(spots, clamp(s.x * size / EDGE_RANGE, 0.0, 1.0), hash1(s.yz), earth);
	} else {
		vec3 s = stones(p / (PERIOD / PEBBLE_CELLS), 0.45, PEBBLE_CELLS);
		bool has = hash1(s.yz + 3.0) < 0.12;
		float d = 0.5 - s.x;
		float pebble = has ? 1.0 - smoothstep(0.3, 0.38, d) : 0.0;
		float rim = has ? smoothstep(0.3, 0.36, d) * (1.0 - smoothstep(0.38, 0.44, d)) : 0.0;
		float earth = mix(0.86 + 0.28 * spots, 1.12, pebble * 0.6) * (1.0 - rim * 0.3);

		float patches = smoothstep(0.35, 0.65, value_noise(p * 6.0 / PERIOD + 4.0, 6.0));
		float tufts = 0.0;
		float shadow = 0.0;
		vec2 q = p / (PERIOD / TUFT_CELLS);
		vec2 cell = floor(q);
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 c = cell + vec2(float(i), float(j));
				vec2 h = wrap(c, TUFT_CELLS);
				if (hash1(h + 9.0) < 0.35) {
					vec2 o = c + 0.2 + 0.6 * hash2(h) - q;
					float r = 0.14 + 0.12 * hash1(h + 2.0);
					tufts = max(tufts, 1.0 - smoothstep(r * 0.6, r, length(o * vec2(1.0, 1.3))));
					shadow = max(shadow, 1.0 - smoothstep(r * 0.6, r, length((o + vec2(0.0, 0.12)) * vec2(1.0, 1.3))));
				}
			}
		}
		float grass = (0.72 + 0.42 * patches + 0.14 * spots) * (1.0 - max(shadow - tufts, 0.0) * 0.3);
		COLOR = vec4(earth / 1.5, grass / 1.5, tufts, 1.0);
	}
}
