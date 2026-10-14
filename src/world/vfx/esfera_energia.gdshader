// Esfera de energía, sin texturas: remolinos de ruido que giran adentro, el borde que brilla (fresnel) y el centro más
// claro. Va en un SphereMesh (el orbe de los enemigos).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled;

instance uniform vec4 color : source_color = vec4(0.45, 0.95, 1.0, 1.0);
uniform float energy = 2.2;
uniform float swirl = 2.5;

varying vec3 local;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec3 p = normalize(local);
	float a = TIME * swirl;
	p.xz = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * p.xz;
	p.y += sin(p.x * 3.0 + TIME * 2.0) * 0.25;
	float n = noise(p * 3.2 + vec3(0.0, TIME * 0.8, 0.0)) * 0.6 + noise(p * 7.0 - vec3(TIME, 0.0, 0.0)) * 0.4;
	float bands = smoothstep(0.48, 0.72, n);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.2);
	float core = pow(facing, 4.0);
	ALBEDO = mix(color.rgb, vec3(1.0), core * 0.6 + bands * 0.25) * energy;
	ALPHA = clamp(bands * 0.75 + rim * 1.3 + core * 0.4, 0.0, 1.0) * color.a;
}
