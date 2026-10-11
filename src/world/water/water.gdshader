// Agua toon: transparente con el color de la franja agua de la paleta según la profundidad (se ve el fondo con sus
// cáusticas), manchas de espuma de borde duro con el patrón compartido y espuma en la orilla por profundidad.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled;

#include "res://src/world/water/water_pattern.gdshaderinc"

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec3 shallow_color : source_color = vec3(0.557, 0.831, 0.894);
uniform vec3 deep_color : source_color = vec3(0.165, 0.416, 0.549);
uniform vec3 foam_color : source_color = vec3(0.93, 0.98, 1.0);
// Metros de agua hasta el color profundo.
uniform float depth_fade = 1.8;
uniform float shallow_alpha = 0.12;
uniform float deep_alpha = 0.45;
// Metros de agua con espuma en la orilla.
uniform float shore_foam = 0.14;
uniform float foam_amount = 0.5;
// Escala del patrón (repeticiones por metro) y velocidad; las cáusticas usan los mismos.
uniform float tile = 2.5;
uniform float speed = 1.2;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	float thickness = max(VERTEX.z - view.z, 0.0);
	float t = clamp(thickness / depth_fade, 0.0, 1.0);
	vec2 layers = water_layers(world_position.xz * tile, vec3(0.0, 1.0, 0.0), TIME * speed);
	float foam = layers.y * foam_amount;
	float shore = step(thickness, shore_foam * (0.75 + 0.5 * layers.x));
	foam = max(foam, shore);
	ALBEDO = mix(mix(shallow_color, deep_color, t), foam_color, foam);
	ALPHA = max(mix(shallow_alpha, deep_alpha, t), foam);
}
