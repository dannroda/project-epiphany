// Espuma al pie de un chorro: anillos de borde duro que se abren y se cortan sobre la superficie del agua.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

#include "res://src/world/water/water_pattern.gdshaderinc"

uniform vec3 foam_color : source_color = vec3(0.93, 0.98, 1.0);
uniform float rings = 3.0;
uniform float speed = 0.9;
uniform float width = 0.32;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float wave = fract(r * rings - TIME * speed);
	float broken = noise(vec2(atan(p.y, p.x) * 3.0, r * 4.0 - TIME * 2.0));
	float ring = step(1.0 - width * (0.6 + 0.8 * broken), wave);
	float core = step(r, 0.28 + 0.08 * broken);
	ALBEDO = foam_color;
	ALPHA = max(ring * (1.0 - smoothstep(0.55, 1.0, r)), core);
}
