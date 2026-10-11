// Chorro de agua toon: vetas de borde duro que bajan, espuma en los costados y al pie, con los colores del agua.
// UV.y va de arriba (0) a abajo (1).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

#include "res://src/world/water/water_pattern.gdshaderinc"

uniform vec3 water_color : source_color = vec3(0.557, 0.831, 0.894);
uniform vec3 deep_color : source_color = vec3(0.165, 0.416, 0.549);
uniform vec3 foam_color : source_color = vec3(0.93, 0.98, 1.0);
uniform float speed = 2.2;
// Vetas a lo ancho y a lo largo del chorro.
uniform vec2 streaks = vec2(6.0, 1.2);
uniform float streak_cut = 0.55;
uniform float edge_foam = 0.12;
uniform float foot_foam = 0.12;
uniform float alpha = 0.85;
uniform float wobble = 0.03;

void vertex() {
	VERTEX.x += sin(VERTEX.y * 6.0 + TIME * 5.0) * wobble * UV.y;
}

void fragment() {
	vec2 flow = vec2(UV.x * streaks.x, UV.y * streaks.y - TIME * speed);
	float n = noise(flow * vec2(1.0, 3.0)) * 0.65 + noise(flow * vec2(2.0, 7.0)) * 0.35;
	float streak = step(streak_cut, n);
	float side = min(UV.x, 1.0 - UV.x);
	float edge = step(side, edge_foam * (0.6 + 0.8 * noise(vec2(UV.y * 9.0 - TIME * speed * 3.0, UV.x * 3.0))));
	float foot = step(1.0 - foot_foam * (0.7 + 0.6 * noise(vec2(UV.x * 10.0, TIME * 4.0))), UV.y);
	float foam = max(edge, foot);
	vec3 body = mix(deep_color, water_color, 0.55 + 0.45 * streak);
	ALBEDO = mix(body, foam_color, max(foam, streak * 0.6));
	ALPHA = mix(alpha, 1.0, foam) * smoothstep(0.0, 0.04, UV.y);
}
