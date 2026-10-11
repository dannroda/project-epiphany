shader_type spatial;
// Terreno de marching cubes (prueba 12.14): el color sale de la paleta según la altura y la pendiente en el mundo, no
// de las UV, así las franjas de la roca y el borde del camino quedan limpios aunque los triángulos no los sigan.
// COLOR.r es un valor al azar por triángulo que corre un poco el tono (como el vary de los kits). Alturas y camino van
// en coordenadas de la malla, así el terreno se puede mover.

#include "cloud_shadows.gdshaderinc"
#include "player_hole.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(0.72, 0.72, 0.72, 1.0);
uniform sampler2D palette : source_color, filter_linear;
uniform sampler2D path_mask : filter_linear;
// xy: esquina (x, z) del mundo que cubre path_mask; zw: tamaño en metros.
uniform vec4 path_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool cut_hole = false;
uniform float top = 2.6;
uniform float cap = 0.15;
uniform float depth = -3.0;
uniform float vary = 0.06;

const int PASTO = 0;
const int TIERRA = 2;
const int ACANTILADO = 3;
const int MUSGO = 7;
const int GRIS_4 = 28;
const int GRIS_5 = 29;
const float MARGIN = 0.06;

varying vec3 world_pos;
varying vec3 local_pos;
varying vec3 local_normal;

// La franja index de la paleta (8 × 4) en el tono t: 0 abajo (oscuro), 1 arriba (claro).
vec3 swatch(int index, float t) {
	float row = float(index / 8);
	float lo = (3.0 - row + MARGIN) / 4.0;
	float hi = (4.0 - row - MARGIN) / 4.0;
	vec2 uv = vec2((float(index % 8) + 0.5) / 8.0, 1.0 - (lo + (hi - lo) * clamp(t, 0.0, 1.0)));
	return texture(palette, uv).rgb;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	if (cut_hole && in_player_hole(world_pos, VERTEX, VIEW_MATRIX, FRAGCOORD.xy)) {
		discard;
	}
	float shift = (COLOR.r - 0.5) * 2.0 * vary;
	float y = local_pos.y;
	float ny = local_normal.y;
	bool wall_band = y > 0.35 && y < top - 0.3;
	float row_height = (top - cap + 0.5) / 6.0;
	vec3 color;
	if (ny < -0.2) {
		color = swatch(ACANTILADO, 0.15 + shift);
	} else if (wall_band && ny > 0.35 && ny < 0.95) {
		color = swatch(MUSGO, 0.5 + shift);
	} else if (ny > 0.7 && y < -0.3) {
		color = swatch(y < depth * 5.0 / 7.0 ? GRIS_5 : GRIS_4, 0.15);
	} else if (ny > 0.7) {
		float path = step(0.5, texture(path_mask, (local_pos.xz - path_rect.xy) / path_rect.zw).r);
		color = mix(swatch(PASTO, 0.5), swatch(TIERRA, 0.5), path);
	} else if (y > top - 0.08) {
		color = swatch(PASTO, 0.15);
	} else if (y < 0.0) {
		if (y > depth * 3.0 / 7.0) {
			color = swatch(ACANTILADO, 0.5 + shift);
		} else if (y > depth * 5.0 / 7.0) {
			color = swatch(GRIS_4, 0.5 + shift);
		} else {
			color = swatch(GRIS_5, 0.15);
		}
	} else {
		int row = int((y + 0.5) / row_height);
		if (row < 2) {
			color = swatch(ACANTILADO, 0.15 + shift);
		} else if (row == 3) {
			color = swatch(TIERRA, (y + 0.5 - row_height * 2.0) / (row_height * 3.0) + shift);
		} else {
			color = swatch(ACANTILADO, (y + 0.5) / (top - cap + 0.5) + shift);
		}
	}
	ALBEDO = albedo_color.rgb * color * cloud_shade(world_pos, TIME);
	ROUGHNESS = 1.0;
}
