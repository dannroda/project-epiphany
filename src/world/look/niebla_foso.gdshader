// Interior de un foso: niebla que se mueve pegada al borde y más abajo negro puro, sin fondo.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 fog_color : source_color = vec3(0.62, 0.68, 0.8);
uniform float fog_amount = 0.85;
uniform float fog_top = -0.15;
uniform float fog_peak = -0.6;
uniform float black_from = -0.9;
uniform float black_to = -2.2;
uniform float drift = 0.08;

varying float height;
varying vec3 world;

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	height = VERTEX.y;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = (world.xz + world.y) * 0.9 + vec2(TIME * drift, TIME * drift * 0.6);
	float n = noise(p) * 0.6 + noise(p * 2.3 - TIME * drift) * 0.4;
	float fog = smoothstep(fog_top, fog_peak, height) * fog_amount * (0.55 + 0.45 * n);
	float black = smoothstep(black_from, black_to, height);
	ALBEDO = fog_color * (1.0 - black);
	ALPHA = clamp(max(fog, black), 0.0, 1.0);
}
