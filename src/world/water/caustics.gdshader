// El agua vista desde una CausticsLight (cada píxel del projector sigue su rayo hasta el plano del agua) o en planta para
// un CausticsDecal, con el mismo patrón que water.gdshader, así las líneas de espuma caen en paredes y piso alineadas con las de la superficie.
// Fuera de la pileta se apaga en outside_reach metros (0 = solo lo que pasa por el agua).
// texture_blit no acepta global uniforms (4.8-dev7): CausticsCanvas copia tile y speed del agua.
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
// Metros hacia adentro del borde en los que se apaga, y hasta dónde se derrama hacia afuera.
uniform float edge_fade = 0.6;
uniform float outside_reach = 0.0;
// Apagado, no ilumina dentro de la pileta (la luz del piso no se encima con el agua).
uniform bool lit_inside = true;
// CausticsDecal: la textura cubre en planta el rectángulo plane_origin..plane_origin + plane_size.
uniform bool planar = false;
uniform vec2 plane_origin = vec2(-2.0);
uniform vec2 plane_size = vec2(4.0);

void blit() {
	vec2 ndc = UV * 2.0 - 1.0;
	vec3 dir = light_basis * normalize(vec3(ndc.x * tan_half_angle, -ndc.y * tan_half_angle, -1.0));
	float c = 0.0;
	float t = abs(dir.y) > 0.001 ? (surface_y - light_origin.y) / dir.y : -1.0;
	if (planar || t > 0.0) {
		vec3 p = planar ? vec3(plane_origin.x + UV.x * plane_size.x, surface_y, plane_origin.y + UV.y * plane_size.y) : light_origin + dir * t;
		vec2 out_of = max(pool_min - p.xz, p.xz - pool_max);
		float signed_edge = max(out_of.x, out_of.y) > 0.0 ? length(max(out_of, vec2(0.0))) : max(out_of.x, out_of.y);
		float edge = 1.0 - smoothstep(-edge_fade, outside_reach, signed_edge);
		if (!lit_inside && signed_edge < 0.0) {
			edge = 0.0;
		}
		vec2 layers = water_layers(p.xz * tile, vec3(0.0, 1.0, 0.0), TIME * speed);
		c = (base_brightness + layers.x * 0.15 + layers.y * foam_brightness) * edge;
	}
	COLOR0 = vec4(tint * c, 1.0);
}
