// Pilar de luz que sube, sin texturas: lenguas de luz de ruido que suben y se apagan arriba, con la base más fuerte y
// los bordes del cilindro más brillantes. Va en un CylinderMesh abierto.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.95, 0.7, 0.3, 1.0);
uniform float energy = 1.8;
uniform float speed = 0.6;
uniform float streaks = 10.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

// Ruido que da la vuelta: period celdas en x y vuelve al principio (sin costura en el cilindro).
float noise(vec2 p, float period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 i0 = vec2(mod(i.x, period), i.y);
	vec2 i1 = vec2(mod(i.x + 1.0, period), i.y);
	return mix(mix(hash(i0), hash(i1), f.x), mix(hash(i0 + vec2(0.0, 1.0)), hash(i1 + vec2(0.0, 1.0)), f.x), f.y);
}

void fragment() {
	float h = 1.0 - UV.y;
	vec2 p = vec2(UV.x * streaks, h * 2.2 - TIME * speed);
	float n = noise(p, streaks) * 0.65 + noise(p * vec2(2.0, 2.3) + vec2(0.0, 7.0), streaks * 2.0) * 0.35;
	float tongues = smoothstep(0.3 + h * 0.55, 0.75 + h * 0.2, n);
	float base = smoothstep(0.18, 0.0, h);
	float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	float fade = pow(1.0 - h, 1.6);
	ALBEDO = color.rgb * energy;
	ALPHA = clamp((tongues * 0.9 + base * 0.8 + edge * 0.25) * fade, 0.0, 1.0) * color.a;
}
