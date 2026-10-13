shader_type spatial;
render_mode cull_disabled;

#include "player_hole.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.5;
uniform float uv_offset = 0.5;
// true: las UV del modelo (piezas de KayKit con su atlas); false: triplanar de mundo (kit gris).
uniform bool use_uv = false;
// Rectángulo XZ (x0, x1, z0, z1) que se recorta por encima de cut_height; lo actualiza la cámara.
uniform vec4 cut_area = vec4(0.0);
uniform float cut_height = 0.0;
// Dentro del recorte, más allá de este z no queda nada: de la pared solo un borde bajo del lado de la sala.
uniform float cut_lip = 1e6;
uniform float back_shade = 0.12;
// Lo de adentro de una pared recortada se ve como su tapa: la textura vista desde arriba, algo más oscura.
uniform float cap_shade = 0.75;
// Brillo de la superficie (los valores por defecto son los de Godot sin tocar).
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
// Veta de madera dibujada en las caras paradas cuyo color de paleta cae en grain_rect (u0, u1, v0, v1); 0 la apaga.
uniform float grain_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 grain_rect = vec4(0.0);
uniform float grain_spacing = 0.2;

varying vec3 world_pos;
varying vec3 world_normal;

float grain_hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

float grain_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(grain_hash(i), grain_hash(i + vec2(1.0, 0.0)), f.x), mix(grain_hash(i + vec2(0.0, 1.0)), grain_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float grain(vec3 pos, vec3 n) {
	float along = n.x > n.z ? pos.z : pos.x;
	float w = along / grain_spacing + 1.2 * grain_noise(vec2(along * 1.5, pos.y * 0.4));
	float fiber = smoothstep(0.09, 0.0, abs(fract(w) - 0.5)) * smoothstep(0.35, 0.6, grain_noise(vec2(floor(w) * 3.7, pos.y * 0.6)));
	float k = grain_noise(vec2(along * 6.0, pos.y * 3.0));
	float knot = smoothstep(0.025, 0.0, abs(k - 0.9)) + smoothstep(0.95, 0.98, k);
	return clamp(fiber + knot, 0.0, 1.0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
}

void fragment() {
	bool in_cut = world_pos.x > cut_area.x && world_pos.x < cut_area.y && world_pos.z > cut_area.z && world_pos.z < cut_area.w;
	if (in_cut && (world_pos.y > cut_height || world_pos.z > cut_lip)) {
		discard;
	}
	if (in_player_hole(world_pos, VERTEX, VIEW_MATRIX, FRAGCOORD.xy)) {
		discard;
	}
	vec3 p = world_pos * uv_scale + uv_offset;
	vec3 tex;
	if (use_uv) {
		tex = texture(albedo_texture, UV).rgb;
	} else {
		vec3 w = world_normal / (world_normal.x + world_normal.y + world_normal.z);
		tex = texture(albedo_texture, p.zy * vec2(1.0, -1.0)).rgb * w.x
			+ texture(albedo_texture, p.xz).rgb * w.y
			+ texture(albedo_texture, p.xy * vec2(1.0, -1.0)).rgb * w.z;
	}
	if (FRONT_FACING) {
		ALBEDO = albedo_color.rgb * tex;
		if (grain_amount > 0.0 && world_normal.y < 0.6 && UV.x > grain_rect.x && UV.x < grain_rect.y && UV.y > grain_rect.z && UV.y < grain_rect.w) {
			ALBEDO *= 1.0 - grain_amount * grain(world_pos, world_normal);
		}
		ROUGHNESS = roughness;
		SPECULAR = specular;
	} else if (in_cut) {
		vec3 top = use_uv ? tex : texture(albedo_texture, p.xz).rgb;
		ALBEDO = albedo_color.rgb * top * cap_shade;
	} else {
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		EMISSION = albedo_color.rgb * back_shade;
	}
}
