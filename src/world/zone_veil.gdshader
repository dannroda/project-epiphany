shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
// Banco de niebla sobre una zona sin ver: borde ondulado (no un cuadrado), nubes que se mueven despacio.
// Al abrirse se disuelve con dither desde reveal_center.

uniform vec4 mist : source_color = vec4(0.8, 0.82, 0.85, 1.0);
uniform vec4 shade : source_color = vec4(0.58, 0.62, 0.68, 1.0);
uniform float edge = 2.0;
instance uniform float fringe = 3.0;
uniform float scale = 0.12;
uniform float drift = 0.03;
instance uniform vec2 reveal_center;
instance uniform float reveal_radius = 0.0;
instance uniform vec4 rect;

varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float clouds(vec2 p) {
	return value_noise(p) * 0.6 + value_noise(p * 2.3 + 7.1) * 0.3 + value_noise(p * 5.1 - 3.7) * 0.1;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dither = fract(sin(dot(floor(FRAGCOORD.xy * 0.5), vec2(12.9898, 78.233))) * 43758.5453);
	if (distance(world.xz, reveal_center) < reveal_radius - edge * dither) {
		discard;
	}
	vec2 p = world.xz * scale + vec2(TIME * drift, TIME * drift * 0.6);
	float inside = min(min(world.x - rect.x, rect.z - world.x), min(world.z - rect.y, rect.w - world.z));
	float wisp = inside / fringe + (value_noise(world.xz * 0.12 + p * 0.5) - 0.5) * 1.1 + (value_noise(world.xz * 0.5 + 11.0) - 0.5) * 0.4;
	if (wisp < dither) {
		discard;
	}
	float puff = clouds(p);
	ALBEDO = mix(shade.rgb, mist.rgb, max(smoothstep(0.3, 0.75, puff), 1.0 - clamp(wisp, 0.0, 1.0)));
}
