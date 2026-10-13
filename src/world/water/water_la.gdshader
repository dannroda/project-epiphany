// Agua a lo Link's Awakening (Switch): el shader del visor de LA (godot_viewer, la_water.gdshader: el modelo de color de
// "bezel_water_basic" transcrito con RenderDoc) con dos cambios: las texturas son nuestras (water_la_*.tres, ruido) en vez
// de las del juego, y la luz de ambiente por sala (SH) es un color, ambient_light.
//   t      = distancia de la superficie al punto de la escena detrás
//   tint   = mix(shallow_water_color, water_color, t / depth_color_range)
//   A      = refr * tint + tint * cáusticas, que va a muddy_color en muddy_range
//   out    = mix(refr, A iluminada * blend_color, t / depth_global_blend_range)
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

group_uniforms textures;
uniform sampler2D wave_normal : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D indirect_normal : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D caustics_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

group_uniforms colors;
uniform vec3 water_color = vec3(0.2, 1.0, 0.75);
uniform vec3 shallow_water_color = vec3(0.8, 1.0, 0.9);
uniform vec3 muddy_color = vec3(0.0, 0.3, 0.4);
uniform vec3 blend_color = vec3(0.0, 0.8, 1.0);
uniform vec3 caustics_blend_color0 = vec3(0.6, 1.0, 1.0);
uniform vec3 caustics_blend_color1 = vec3(0.0, 0.5, 0.8);
// Luz de la sala que ilumina el agua (en LA, la SH de la sala): la de Lv04 mirando arriba.
uniform vec3 ambient_light = vec3(0.68, 1.05, 1.14);

group_uniforms depth;
uniform float depth_color_range = 0.5;
uniform float depth_refract_range = 4.0;
uniform float depth_global_blend_range = 0.5;
uniform float muddy_range = 30.0;

group_uniforms surface;
uniform float uv_world_position_scale = 12.0;
uniform float bump_scale = 0.3;
uniform float bump_scale2 = 0.45;
uniform vec2 ind_scale = vec2(0.05, 0.05);
uniform float refract_scale = 0.3;
uniform float shallow_refract_scale = 0.05;
uniform float smoothness = 0.5;
uniform float metalness = 0.5;

group_uniforms uv_transforms;
// TexSrt: x = escala, y = rotación (radianes); la traslación se anima abajo.
uniform vec2 texsrt0 = vec2(2.0, 2.6179938);
uniform vec2 texsrt1 = vec2(2.0, 0.0);
uniform vec2 texsrt2 = vec2(3.0, 0.17453292);
uniform vec2 caustics_texsrt0 = vec2(0.5, 2.6179938);
uniform vec2 caustics_texsrt1 = vec2(0.5, 0.17453292);

group_uniforms animation;
uniform float wave_speed0 = 0.02;
uniform float wave_speed2 = 0.015;
uniform float ind_speed = 0.01;
uniform float caustics_speed0 = 0.012;
uniform float caustics_speed1 = 0.009;
uniform float caustics_strength = 1.0;

varying vec3 world_pos;

vec2 srt(vec2 uv, vec2 sr, float scroll) {
	float c = cos(sr.y), s = sin(sr.y);
	uv *= sr.x;
	uv = vec2(c * uv.x - s * uv.y, s * uv.x + c * uv.y);
	return uv + vec2(scroll);
}

vec2 sample_xy(sampler2D t, vec2 uv) {
	return texture(t, uv).rg * 2.0 - 1.0;
}

vec3 view_pos(vec2 uv, float depth, mat4 inv_proj) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return v.xyz / v.w;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float tm = mod(TIME, 1000.0);
	vec2 base_uv = world_pos.xz / uv_world_position_scale;

	vec2 ind = sample_xy(indirect_normal, srt(base_uv, texsrt1, tm * ind_speed)) * ind_scale;
	// Dos capas de olas combinadas como en el juego (reoriented normal mapping).
	vec2 a = sample_xy(wave_normal, srt(base_uv, texsrt0, tm * wave_speed0) + ind) * bump_scale;
	vec2 b = sample_xy(wave_normal, srt(base_uv, texsrt2, -tm * wave_speed2) + ind) * bump_scale2;
	vec3 n1 = vec3(a, sqrt(clamp(1.0 - dot(a, a), 0.0, 1.0)) + 1.0);
	vec3 n2 = vec3(-b, sqrt(clamp(1.0 - dot(b, b), 0.0, 1.0)));
	vec3 nt = normalize(n1 * dot(n1, n2) / n1.z - n2);
	vec3 n_world = normalize(vec3(nt.x, nt.z, nt.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	float t = max(length(view_pos(SCREEN_UV, texture(depth_tex, SCREEN_UV).r, INV_PROJECTION_MATRIX)) - length(VERTEX), 0.0);

	float refr_amt = mix(shallow_refract_scale, refract_scale, clamp(t / depth_refract_range, 0.0, 1.0));
	vec2 refr_uv = SCREEN_UV + clamp(nt.xy * refr_amt, vec2(-0.1), vec2(0.1)) * 0.1;
	if (view_pos(refr_uv, texture(depth_tex, refr_uv).r, INV_PROJECTION_MATRIX).z > VERTEX.z) refr_uv = SCREEN_UV;
	vec3 refr = texture(screen_tex, refr_uv).rgb;

	vec3 tint = mix(shallow_water_color, water_color, clamp(t / depth_color_range, 0.0, 1.0));
	vec3 c0 = texture(caustics_tex, srt(base_uv, caustics_texsrt0, tm * caustics_speed0) + ind).rgb;
	vec3 c1 = texture(caustics_tex, srt(base_uv, caustics_texsrt1, -tm * caustics_speed1) + ind).rgb;
	vec3 A = refr * tint + caustics_strength * tint * (c0 * caustics_blend_color0 + c1 * caustics_blend_color1);
	A = mix(A, caustics_strength * muddy_color, clamp(t / muddy_range, 0.0, 1.0));

	vec3 alb = A * blend_color;
	ALBEDO = alb;
	METALLIC = metalness;
	ROUGHNESS = 1.0 - smoothness;
	EMISSION = alb * (1.0 - metalness) * ambient_light;
	ALPHA = clamp(t / depth_global_blend_range, 0.0, 1.0);
}
