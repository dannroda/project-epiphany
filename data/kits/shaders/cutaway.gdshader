shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.5;
uniform float uv_offset = 0.5;
// Rectángulo XZ (x0, x1, z0, z1) que se recorta por encima de cut_height; lo actualiza la cámara.
uniform vec4 cut_area = vec4(0.0);
uniform float cut_height = 0.0;
uniform float back_shade = 0.12;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
}

void fragment() {
	bool in_cut = world_pos.x > cut_area.x && world_pos.x < cut_area.y && world_pos.z > cut_area.z && world_pos.z < cut_area.w;
	if (in_cut && world_pos.y > cut_height) {
		discard;
	}
	vec3 p = world_pos * uv_scale + uv_offset;
	vec3 w = world_normal / (world_normal.x + world_normal.y + world_normal.z);
	vec3 tex = texture(albedo_texture, p.zy * vec2(1.0, -1.0)).rgb * w.x
		+ texture(albedo_texture, p.xz).rgb * w.y
		+ texture(albedo_texture, p.xy * vec2(1.0, -1.0)).rgb * w.z;
	if (FRONT_FACING && !in_cut) {
		ALBEDO = albedo_color.rgb * tex;
	} else {
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		EMISSION = albedo_color.rgb * back_shade;
	}
}
