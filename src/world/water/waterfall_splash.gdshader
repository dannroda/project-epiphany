// Espuma al pie de un chorro: una mancha de borde duro que se revuelve, con huecos y pedazos sueltos alrededor.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

#include "res://src/world/water/water_pattern.gdshaderinc"

uniform vec3 foam_color : source_color = vec3(0.93, 0.98, 1.0);
uniform vec3 shade_color : source_color = vec3(0.72, 0.88, 0.95);
// Escala de la mancha respecto del plano y velocidad del revuelo.
uniform float size = 0.6;
uniform float churn = 1.6;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float t = TIME * churn;
	float n = noise(p * 3.0 + vec2(0.0, -t)) * 0.6 + noise(p * 6.0 + vec2(t * 0.8, -t * 0.5)) * 0.4;
	float body = step(r, size * (0.65 + 0.6 * n));
	float holes = step(0.78, noise(p * 9.0 - vec2(t * 1.3, t))) * step(size * 0.45, r);
	float bits = step(0.8, noise(p * 7.0 + vec2(t * 0.4, -t * 0.9))) * step(r, 0.95);
	float foam = max(body * (1.0 - holes), bits);
	ALBEDO = mix(shade_color, foam_color, step(r, size * (0.45 + 0.4 * n)));
	ALPHA = foam;
}
