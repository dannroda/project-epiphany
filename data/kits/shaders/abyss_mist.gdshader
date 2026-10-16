shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Niebla del abismo: capas que se corren despacio y tapan el fondo, más espesas cuanto más abajo.

uniform vec4 color : source_color = vec4(0.8, 0.82, 0.88, 1.0);
uniform float density = 0.6;
uniform vec2 drift = vec2(0.22, 0.08);
uniform float scale = 0.45;

varying vec3 world_pos;

float mist_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float mist_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mist_hash(i), mist_hash(i + vec2(1.0, 0.0)), f.x),
			mix(mist_hash(i + vec2(0.0, 1.0)), mist_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * scale + drift * TIME * (1.0 - world_pos.y * 0.4) + world_pos.y * 7.3;
	float n = mist_noise(p) * 0.6 + mist_noise(p * 2.2 + 5.0) * 0.4;
	ALBEDO = color.rgb;
	ALPHA = density * smoothstep(0.2, 0.75, n) * clamp(0.25 - world_pos.y * 0.3, 0.0, 1.0);
}
