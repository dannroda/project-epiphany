// Piso de losas a lo Link's Awakening: sobre el color de la paleta, losas de piedra irregulares en coordenadas de mundo
// (sin costuras entre piezas) con juntas oscuras, tono propio por losa, manchas, alguna grieta y el borde biselado que
// agarra el brillo. Solo en las caras de arriba; los costados quedan con la paleta.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 albedo_color : source_color = vec4(0.72, 0.72, 0.72, 1.0);
// Metros por losa (en promedio) y cuánto se corren sus esquinas.
uniform float tile_size = 1.5;
uniform float jitter : hint_range(0.0, 0.45) = 0.12;
uniform float grout_width = 0.035;
uniform float grout_shade : hint_range(0.0, 1.0) = 0.45;
uniform float bevel = 0.09;
uniform float tone_spread : hint_range(0.0, 0.5) = 0.18;
uniform float mottle : hint_range(0.0, 0.5) = 0.12;
uniform float crack_amount : hint_range(0.0, 1.0) = 0.15;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float specular : hint_range(0.0, 1.0) = 0.4;
uniform float normal_strength = 0.6;

varying vec3 world_pos;
varying vec3 world_normal;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash1(i), hash1(i + vec2(1.0, 0.0)), f.x), mix(hash1(i + vec2(0.0, 1.0)), hash1(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Voronoi con borde: distancia al borde de la losa (F2 - F1 aproximado por el plano medio) y el id de la losa.
vec3 stones(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	vec2 best_cell = vec2(0.0);
	vec2 best_r = vec2(0.0);
	float d1 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + 0.5 + (hash2(n + g) - 0.5) * 2.0 * jitter - f;
			float d = dot(r, r);
			if (d < d1) {
				d1 = d;
				best_r = r;
				best_cell = n + g;
			}
		}
	}
	float edge = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + 0.5 + (hash2(n + g) - 0.5) * 2.0 * jitter - f;
			vec2 diff = r - best_r;
			if (dot(diff, diff) > 0.0001) {
				edge = min(edge, dot(0.5 * (best_r + r), normalize(diff)));
			}
		}
	}
	return vec3(edge, best_cell);
}

float stone_height(vec2 p) {
	vec3 s = stones(p / tile_size);
	return smoothstep(0.0, bevel / tile_size, s.x - grout_width / tile_size);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = albedo_color.rgb * texture(albedo_texture, UV).rgb;
	if (world_normal.y < 0.9) {
		ALBEDO = base;
		ROUGHNESS = 1.0;
	} else {
		vec2 p = world_pos.xz;
		vec3 s = stones(p / tile_size);
		float edge = s.x * tile_size;
		float tone = 1.0 + (hash1(s.yz) - 0.5) * 2.0 * tone_spread;
		float spots = value_noise(p * 1.7) * 0.6 + value_noise(p * 5.3) * 0.4;
		float shade = tone * (1.0 - mottle + mottle * 2.0 * spots);
		float crack_line = abs(value_noise(p * 2.2 + s.yz * 3.1) - 0.5);
		float crack = step(hash1(s.yz + 7.0), crack_amount) * smoothstep(0.015, 0.0, crack_line) * smoothstep(grout_width, grout_width + 0.15, edge);
		float grout = 1.0 - smoothstep(grout_width * 0.5, grout_width, edge);
		vec3 color = base * shade;
		color *= 1.0 - crack * 0.5;
		color = mix(color, base * grout_shade, grout);
		ALBEDO = color;
		float e = 0.02;
		float h = stone_height(p);
		vec2 slope = vec2(stone_height(p + vec2(e, 0.0)) - h, stone_height(p + vec2(0.0, e)) - h) / e;
		vec3 n = normalize(vec3(-slope.x * normal_strength * bevel, 1.0, -slope.y * normal_strength * bevel));
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
		ROUGHNESS = mix(roughness, 1.0, grout);
		SPECULAR = specular * (1.0 - grout);
	}
}
