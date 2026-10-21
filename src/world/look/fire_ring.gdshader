// Pared de llamas de un cilindro abierto (FireRing): lenguas que suben y titilan a lo largo de la circunferencia, con el
// centro claro. `reveal` las hace crecer desde el piso (0 = apagado, 1 = a toda altura).
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 core_color : source_color = vec3(1.0, 0.85, 0.45);
uniform vec3 edge_color : source_color = vec3(1.0, 0.3, 0.05);
uniform float intensity = 4.0;
uniform float tongues = 60.0;
uniform float speed = 1.6;
uniform float reveal : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float y = 1.0 - UV.y;
	float x = UV.x * tongues;
	float n = noise(vec2(x * 0.7, y * 3.0 - TIME * speed * 2.0));
	float n2 = noise(vec2(x * 1.9 + 7.0, y * 5.0 - TIME * speed * 3.1));
	float top = (0.35 + 0.65 * n * (0.6 + 0.4 * n2)) * reveal;
	float flame = 1.0 - smoothstep(top - 0.25, top, y);
	float core = 1.0 - smoothstep(top * 0.3, top * 0.6, y);
	ALBEDO = (edge_color + core_color * core) * flame * intensity;
}
