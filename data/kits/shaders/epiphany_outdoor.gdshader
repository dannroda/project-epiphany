shader_type spatial;
// El material de paleta (epiphany.tres) para lo de afuera: con sombras de nubes, viento (wind.gdshaderinc) y el brillo
// de las mazmorras (palette_surface). En las caras de arriba, detalle en coordenadas de mundo según el color: losas
// sueltas con tierra entre medio en la piedra (floor_earth: 0 = todo losas, epiphany_outdoor_losas.tres), piedritas en la tierra y
// parches con matitas en el pasto.

#include "cloud_shadows.gdshaderinc"
#include "wind.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(0.72, 0.72, 0.72, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D emission_texture : source_color, hint_default_black, filter_linear_mipmap;
uniform sampler2D surface_texture : hint_default_white, filter_nearest;
uniform float emission_energy = 1.5;
uniform float detail = 1.0;
uniform float floor_earth = 0.6;


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

vec3 stones(vec2 p, float jitter) {
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

float tile_height(vec2 p, float size, float jitter, float grout) {
	vec3 s = stones(p / size, jitter);
	return smoothstep(0.0, 0.09, s.x * size - grout);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	VERTEX += wind_offset(UV, world_pos, MODEL_MATRIX);
}

void fragment() {
	vec3 base = albedo_color.rgb * texture(albedo_texture, UV).rgb;
	vec4 surface = texture(surface_texture, UV);
	float rough = surface.g;
	float swatch = floor(UV.x * COLS) + floor(UV.y * ROWS) * COLS;
	vec2 p = world_pos.xz;
	vec3 color = base;
	if (world_normal.y > 0.8 && detail > 0.0) {
		float spots = value_noise(p * 0.35) * 0.55 + value_noise(p * 1.9) * 0.3 + value_noise(p * 7.0) * 0.15;
		if (swatch == 5.0 || swatch == 6.0 || swatch == 15.0) {
			float size = 1.1;
			vec3 s = stones(p / size, 0.38);
			bool dirt = hash1(s.yz + 11.0) < floor_earth;
			float edge = s.x * size;
			float tone = dirt ? 0.64 : 1.0 + (hash1(s.yz) - 0.5) * 0.3;
			float grout = dirt ? 0.0 : 1.0 - smoothstep(0.025, 0.05, edge);
			color = base * tone * (0.88 + 0.24 * spots);
			color = mix(color, base * 0.45, grout);
			if (!dirt) {
				float e = 0.02;
				float h = tile_height(p, size, 0.38, 0.05);
				vec2 slope = vec2(tile_height(p + vec2(e, 0.0), size, 0.38, 0.05) - h, tile_height(p + vec2(0.0, e), size, 0.38, 0.05) - h) / e;
				vec3 n = normalize(vec3(-slope.x * 0.6 * 0.09, 1.0, -slope.y * 0.6 * 0.09));
				NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
			}
			rough = dirt ? 1.0 : mix(rough, 1.0, grout);
		} else if (swatch == 2.0 || swatch == 3.0) {
			vec3 s = stones(p / 0.35, 0.45);
			bool has = hash1(s.yz + 3.0) < 0.12;
			float d = 0.5 - s.x;
			float pebble = has ? 1.0 - smoothstep(0.3, 0.38, d) : 0.0;
			float rim = has ? smoothstep(0.3, 0.36, d) * (1.0 - smoothstep(0.38, 0.44, d)) : 0.0;
			color = base * (0.86 + 0.28 * spots);
			color = mix(color, base * 1.12, pebble * 0.6);
			color *= 1.0 - rim * 0.3;
		} else if (swatch == 0.0 || swatch == 7.0) {
			float patches = smoothstep(0.35, 0.65, value_noise(p * 0.22 + 4.0));
			float tufts = 0.0;
			float shadow = 0.0;
			vec2 q = p / 0.7;
			vec2 cell = floor(q);
			for (int j = -1; j <= 1; j++) {
				for (int i = -1; i <= 1; i++) {
					vec2 c = cell + vec2(float(i), float(j));
					if (hash1(c + 9.0) < 0.35) {
						vec2 o = c + 0.2 + 0.6 * hash2(c) - q;
						float r = 0.14 + 0.12 * hash1(c + 2.0);
						tufts = max(tufts, 1.0 - smoothstep(r * 0.6, r, length(o * vec2(1.0, 1.3))));
						shadow = max(shadow, 1.0 - smoothstep(r * 0.6, r, length((o + vec2(0.0, 0.12)) * vec2(1.0, 1.3))));
					}
				}
			}
			color = base * (0.72 + 0.42 * patches + 0.14 * spots);
			color *= 1.0 - max(shadow - tufts, 0.0) * 0.3;
			color = mix(color, base * vec3(1.2, 1.25, 1.05), tufts * 0.7);
		}
	}
	ALBEDO = color * cloud_shade(world_pos, TIME);
	METALLIC = surface.r;
	ROUGHNESS = rough;
	EMISSION = texture(emission_texture, UV).rgb * emission_energy;
}
