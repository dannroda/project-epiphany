// Anillo de fuego que se abre en el piso (la explosión de la bomba), en un PlaneMesh: `progress` 0..1 lo agranda del
// centro al borde del quad; lenguas de ruido le comen el borde de afuera, claro adentro y rojo afuera, y se apaga al
// final.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 hot : source_color = vec4(1.0, 0.86, 0.5, 1.0);
uniform vec4 fire : source_color = vec4(1.0, 0.32, 0.08, 1.0);
uniform float energy = 1.5;
instance uniform float progress = 1.0;

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
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q);
	vec2 around = q / max(r, 0.001);
	float p = 1.0 - pow(1.0 - clamp(progress, 0.0, 1.0), 3.0);
	float radius = mix(0.12, 0.8, p);
	float width = mix(0.22, 0.1, p);
	float n = noise(around * 4.0 + vec2(progress * 5.0, 0.0)) * 0.6 + noise(around * 9.0 - vec2(0.0, progress * 7.0)) * 0.4;
	float outer = radius + width * (0.2 + 3.2 * n * n);
	float body = smoothstep(radius - width, radius, r) * (1.0 - smoothstep(radius, outer, r));
	float core = 1.0 - smoothstep(0.0, width * 0.35, abs(r - radius));
	float ember = (1.0 - smoothstep(0.0, radius, r)) * 0.18 * (1.0 - p);
	float fade = 1.0 - smoothstep(0.45, 1.0, progress);
	ALBEDO = mix(fire.rgb, hot.rgb, core * 0.8) * energy;
	ALPHA = clamp(body * (0.6 + 0.6 * n) + core * 0.5 + ember, 0.0, 1.0) * fade;
}
