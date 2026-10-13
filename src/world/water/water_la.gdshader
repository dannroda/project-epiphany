// Agua a lo Link's Awakening (Switch): el shader del visor de LA (godot_viewer, la_water.gdshader: la recreación de
// "bezel_water_basic" calibrada contra capturas del juego) con dos cambios: las texturas son nuestras (water_la_*.tres,
// ruido) en vez de las del juego, y la luz de ambiente por sala (SH) es un color, ambient_light.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

group_uniforms textures;
uniform sampler2D wave_normal : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D indirect_normal : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D caustics_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

group_uniforms colors;
// Game colour params are linear (verified against a capture: tint x room SH light = the in-game blue).
uniform vec3 water_color = vec3(0.2, 1.0, 0.75);
uniform vec3 shallow_water_color = vec3(0.8, 1.0, 0.9);
uniform vec3 muddy_color = vec3(0.0, 0.3, 0.4);
uniform vec3 blend_color = vec3(0.0, 0.8, 1.0);
uniform vec3 caustics_blend_color0 = vec3(0.6, 1.0, 1.0);
uniform vec3 caustics_blend_color1 = vec3(0.0, 0.5, 0.8);

group_uniforms depth;
uniform float depth_color_range = 0.5;
uniform float depth_refract_range = 4.0;
uniform float depth_global_blend_range = 0.5;
uniform float muddy_range = 30.0;
// Opacity reached at full depth_global_blend_range (guess: game uses 0x5C/255 ~ 0.36 as base alpha).
uniform float deep_opacity : hint_range(0.0, 1.0) = 0.85;
uniform float shallow_opacity : hint_range(0.0, 1.0) = 0.36;

group_uniforms surface;
// UVs come from world XZ position (uv_world_position=1). World units per UV tile.
// The game's value is 36, but its exact meaning in the shader is unknown; 12 matches better visually.
uniform float uv_world_position_scale = 12.0;
uniform float bump_scale = 0.3;      // bumpScale  (layer texsrt0)
uniform float bump_scale2 = 0.45;    // bumpScale2 (layer texsrt2)
uniform vec2 ind_scale = vec2(0.05, 0.05);
uniform float refract_scale = 0.3;
uniform float shallow_refract_scale = 0.05;
uniform float fresnel_coeff = 0.1;
uniform float smoothness = 0.5;
uniform float metalness = 0.5;

group_uniforms uv_transforms;
// Nintendo TexSrt: x = scale, y = rotation (radians). Translation is animated below.
uniform vec2 texsrt0 = vec2(2.0, 2.6179938);
uniform vec2 texsrt1 = vec2(2.0, 0.0);          // indirect map
uniform vec2 texsrt2 = vec2(3.0, 0.17453292);
uniform vec2 caustics_texsrt0 = vec2(0.5, 2.6179938);
uniform vec2 caustics_texsrt1 = vec2(0.5, 0.17453292);

group_uniforms animation;
// Scroll speeds in UV/second along each layer's rotated axis (guess).
uniform float wave_speed0 = 0.02;
uniform float wave_speed2 = 0.015;
uniform float ind_speed = 0.01;
uniform float caustics_speed0 = 0.012;
uniform float caustics_speed1 = 0.009;
uniform float caustics_strength = 1.0;   // (guess)
uniform float body_amount : hint_range(0.0, 1.0) = 0.35;
uniform float absorption = 0.28;   // (calibrated) 1/m  // (guess) scattering vs transmission
uniform float roughness_scale = 0.8;
uniform float caustics_floor = 0.8;  // (guess) caustics contrast on the floor seen through the water
uniform float glint_scale = 4.0;     // (guess) fine wave detail that breaks highlights into sparkles
uniform float glint_bump = 0.35;   // (guess) sharper wave sparkles
uniform vec3 reflection_color : source_color = vec3(0.75, 0.9, 1.0);  // fake sky reflection (guess)
// Luz de la sala que el agua dispersa hacia la cámara: la SH de Lv04 evaluada a 45° entre arriba y el sur.
uniform vec3 ambient_light = vec3(0.68, 1.05, 1.14);

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = mod(TIME, 1000.0);
	vec2 base_uv = world_pos.xz / uv_world_position_scale;

	// Indirect (distortion) map offsets the other lookups.
	vec2 ind = sample_xy(indirect_normal, srt(base_uv, texsrt1, t * ind_speed)) * ind_scale;

	// Two wave normal layers, both from the same texture.
	vec2 n0 = sample_xy(wave_normal, srt(base_uv, texsrt0, t * wave_speed0) + ind) * bump_scale;
	vec2 n2 = sample_xy(wave_normal, srt(base_uv, texsrt2, -t * wave_speed2) + ind) * bump_scale2;
	// Fine, fast detail layer: only used for the shading normal, so spot highlights break into glints.
	vec2 nf = sample_xy(wave_normal, srt(base_uv * glint_scale, texsrt2, t * wave_speed0 * 2.0) + ind) * glint_bump;
	vec2 nxy = n0 + n2 + nf;
	vec3 n_world = normalize(vec3(nxy.x, 1.0, nxy.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	// Water thickness from the depth buffer.
	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	scene_view.xyz /= scene_view.w;
	float thickness = max(-scene_view.z + VERTEX.z, 0.0);

	// Refraction: stronger in deep water.
	float refr_amt = mix(shallow_refract_scale, refract_scale, clamp(thickness / depth_refract_range, 0.0, 1.0));
	vec2 refr_uv = SCREEN_UV + nxy * refr_amt * 0.1;
	// Avoid pulling in geometry in front of the water.
	float refr_depth = texture(depth_tex, refr_uv).r;
	vec4 refr_view = INV_PROJECTION_MATRIX * vec4(refr_uv * 2.0 - 1.0, refr_depth, 1.0);
	if (refr_view.z / refr_view.w > VERTEX.z) refr_uv = SCREEN_UV;
	vec3 background = texture(screen_tex, refr_uv).rgb;

	// Depth-based tint: shallow -> water -> muddy. The game colours are a transmission tint,
	// they only look blue because the room light (SH ambient + cool spots) is blue.
	float dc = clamp(thickness / depth_color_range, 0.0, 1.0);
	vec3 tint = mix(shallow_water_color, water_color, dc);
	tint = mix(tint, muddy_color, clamp(thickness / muddy_range, 0.0, 1.0));
	tint *= blend_color;

	// Caustics (two rotated layers, distorted by the indirect map), projected on the floor below.
	float c0 = texture(caustics_tex, srt(base_uv, caustics_texsrt0, t * caustics_speed0) + ind * 2.0).r;
	float c1 = texture(caustics_tex, srt(base_uv, caustics_texsrt1, -t * caustics_speed1) + ind * 2.0).r;
	vec3 caustics = (c0 * caustics_blend_color0 + c1 * caustics_blend_color1) * caustics_strength;
	caustics *= 1.0 - 0.6 * clamp(thickness / depth_refract_range, 0.0, 1.0);

	// Light that reaches the floor and comes back up is absorbed with depth: deep water is darker
	// (calibrated: in-game deep / shallow brightness is about 1/3 for 3 m vs 0.5 m of water).
	float absorb = exp(-thickness * absorption);
	float body = mix(shallow_opacity, deep_opacity, clamp(thickness / depth_global_blend_range, 0.0, 1.0));

	// See-through part: the floor (already lit). Shallow water is clear and neutral (the in-game
	// shallows keep the floor's red), the tint only builds up towards depth_refract_range.
	vec3 trans = mix(vec3(1.0), tint, clamp(thickness / depth_refract_range, 0.0, 1.0)) * absorb;
	// Caustic light patterns modulate the visible floor (the mottling seen in game).
	EMISSION = background * trans * (1.0 - body * body_amount) * (0.7 + caustics * caustics_floor);
	// Body part: scattered room light (SH ambient, plus the spots through ALBEDO), with caustic sparkles.
	vec3 scatter = tint * body * body_amount * absorb * (1.0 + caustics * 0.6);
	ALBEDO = scatter * 0.5;
	// Light scattered towards the camera mostly arrives from the camera side (south), not from straight
	// above: evaluate the room SH halfway between up and south (matches the in-game green/blue ratio).
	EMISSION += scatter * ambient_light;
	// Sharp sparkles: game smoothness 0.5 is perceptual, roughness = (1 - s)^2.
	METALLIC = 0.0;
	ROUGHNESS = 0.08;   // very smooth surface + bumpy normal = small sparkles instead of one hot spot
	SPECULAR = 0.15;   // calibrated: no hot spot under the spot lights in the capture
}
