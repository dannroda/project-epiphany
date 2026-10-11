// Reflejo del agua en las paredes: la luz (bajo la superficie, mirando hacia arriba) proyecta el agua tal como se ve.
// Cada píxel sigue su rayo hasta el plano del agua y lee ahí el mismo patrón que water.gdshader, así las líneas de
// espuma caen en la pared alineadas con las de la superficie; los rayos que no pasan por la pileta quedan negros.
// texture_blit no acepta global uniforms (4.8-dev7): WaterPool copia tile y speed del agua y la pose de la luz.
shader_type texture_blit;
render_mode blend_disabled;

#include "res://src/world/water/water_pattern.gdshaderinc"

uniform float tile = 2.5;
uniform float speed = 1.2;
uniform mat3 light_basis = mat3(1.0);
uniform vec3 light_origin = vec3(0.0);
uniform float tan_half_angle = 1.0;
uniform float surface_y = 0.0;
// Rectángulo XZ de la pileta, en mundo.
uniform vec2 pool_min = vec2(-2.0);
uniform vec2 pool_max = vec2(2.0);
uniform vec3 tint : source_color = vec3(0.75, 0.97, 1.0);
uniform float foam_brightness = 1.6;
uniform float base_brightness = 0.15;
// Metros desde el borde de la pileta en los que el reflejo se apaga.
uniform float edge_fade = 0.6;

void blit() {
	vec2 ndc = UV * 2.0 - 1.0;
	vec3 dir = light_basis * normalize(vec3(ndc.x * tan_half_angle, -ndc.y * tan_half_angle, -1.0));
	float c = 0.0;
	if (dir.y > 0.001) {
		vec3 p = light_origin + dir * (surface_y - light_origin.y) / dir.y;
		vec2 inside = min(p.xz - pool_min, pool_max - p.xz);
		float edge = smoothstep(0.0, edge_fade, min(inside.x, inside.y));
		vec2 layers = water_layers(p.xz * tile, vec3(0.0, 1.0, 0.0), TIME * speed);
		c = (base_brightness + layers.x * 0.15 + layers.y * foam_brightness) * edge;
	}
	COLOR0 = vec4(tint * c, 1.0);
}
