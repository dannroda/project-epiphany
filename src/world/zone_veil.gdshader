shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, blend_mix, depth_prepass_alpha;
// Banco de niebla sobre una zona sin ver: opaco adentro, el borde se deshace en jirones transparentes (sin tramado) y
// las nubes se mueven despacio. Al abrirse se disuelve con un borde suave desde reveal_center.

uniform vec4 mist : source_color = vec4(0.86, 0.88, 0.9, 1.0);
uniform vec4 shade : source_color = vec4(0.66, 0.7, 0.76, 1.0);
uniform float edge = 2.0;
instance uniform float fringe = 3.0;
uniform float scale = 0.08;
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
	return value_noise(p) * 0.55 + value_noise(p * 2.1 + 7.1) * 0.3 + value_noise(p * 4.3 - 3.7) * 0.15;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz * scale + vec2(TIME * drift, TIME * drift * 0.6);
	float inside = min(min(world.x - rect.x, rect.z - world.x), min(world.z - rect.y, rect.w - world.z));
	float wisp = inside / fringe + (clouds(world.xz * 0.15 + p) - 0.5) * 0.9;
	float alpha = smoothstep(0.0, 1.0, wisp);
	if (reveal_radius > 0.0) {
		float d = distance(world.xz, reveal_center) - reveal_radius + (clouds(world.xz * 0.2) - 0.5) * edge * 2.0;
		alpha *= smoothstep(0.0, edge * 2.0, d);
	}
	if (alpha < 0.01) {
		discard;
	}
	float puff = clouds(p);
	vec3 color = mix(shade.rgb, mist.rgb, smoothstep(0.3, 0.75, puff));
	ALBEDO = mix(mist.rgb, color, clamp(wisp, 0.0, 1.0));
	ALPHA = alpha;
}
