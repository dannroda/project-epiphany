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

varying vec3 world_pos;
varying vec3 world_normal;

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
	} else if (in_cut) {
		vec3 top = use_uv ? tex : texture(albedo_texture, p.xz).rgb;
		ALBEDO = albedo_color.rgb * top * cap_shade;
	} else {
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		EMISSION = albedo_color.rgb * back_shade;
	}
}
