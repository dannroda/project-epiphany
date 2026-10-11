// Cáusticas del agua: la luz del projector dibuja el mismo patrón que la espuma de la superficie (water.gdshader).
// texture_blit no acepta global uniforms (4.8-dev7): WaterPool les copia tile y speed del material del agua.
shader_type texture_blit;
render_mode blend_disabled;

#include "res://src/world/water/water_pattern.gdshaderinc"

uniform float tile = 2.5;
uniform float speed = 1.2;
// Parche de mundo (XZ) que cubre la textura; lo setea WaterPool según la luz.
uniform vec2 world_origin = vec2(-2.0);
uniform vec2 world_size = vec2(4.0);
uniform vec3 tint : source_color = vec3(0.75, 0.97, 1.0);
uniform float foam_brightness = 1.6;
uniform float base_brightness = 0.12;

void blit() {
	vec2 p = world_origin + UV * world_size;
	vec2 layers = water_layers(p * tile, vec3(0.0, 1.0, 0.0), TIME * speed);
	float c = base_brightness + layers.x * 0.15 + layers.y * foam_brightness;
	// Sin borde cuadrado del projector.
	float falloff = 1.0 - smoothstep(0.65, 1.0, length(UV - 0.5) * 2.0);
	COLOR0 = vec4(tint * c * falloff, 1.0);
}
