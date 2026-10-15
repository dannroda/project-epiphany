shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Onda del grito: varias líneas finas onduladas y punteadas, como una onda de sonido; las de afuera en `outer`, las de
// adentro en `inner`. El plano mide 2 (radio 1).

instance uniform vec4 outer : source_color = vec4(0.35, 0.75, 1.0, 1.0);
instance uniform vec4 inner : source_color = vec4(1.0, 0.7, 0.9, 1.0);
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
uniform int lines = 7;
uniform float wobble = 0.09;
uniform float thickness = 0.016;
uniform float dots = 180.0;
uniform float energy = 1.3;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 dir = p / max(r, 0.0001);
	float a = atan(p.y, p.x);
	vec3 color = vec3(0.0);
	float alpha = 0.0;
	for (int i = 0; i < lines; i++) {
		float k = float(i) / float(max(lines - 1, 1));
		vec2 q = dir * (2.5 + k * 1.5) + vec2(seed * 3.1 + float(i) * 5.7, TIME * (0.6 + k));
		float radius = 0.78 + 0.12 * k + wobble * (noise(q) * 2.0 - 1.0) + wobble * 0.5 * (noise(q * 2.3) - 0.5);
		float line = 1.0 - smoothstep(0.0, thickness * (1.0 + k), abs(r - radius));
		float dotted = smoothstep(0.2, 0.7, 0.5 + 0.5 * sin(a * dots * (0.8 + 0.3 * k) + float(i)));
		float glow = line * mix(1.0, dotted, 0.75);
		color += mix(inner.rgb, outer.rgb, k) * glow;
		alpha += glow;
	}
	ALBEDO = color / max(alpha, 0.001) * energy;
	ALPHA = clamp(alpha * 1.4, 0.0, 1.0) * fade * outer.a;
}
