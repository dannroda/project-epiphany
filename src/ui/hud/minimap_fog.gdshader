shader_type canvas_item;
// Niebla del minimapa del overworld: donde todavía no se pasó, la foto queda en boceto; el mundo termina en tinta.

#include "res://src/ui/map_sketch.gdshaderinc"

// Lo descubierto (GameState.map_revealed): 1 = visto; cubre world_rect.
uniform sampler2D explored : hint_default_black, filter_linear, repeat_disable;
uniform vec4 world_rect;
// Qué rectángulo del mundo (x, z, ancho, alto) muestra la vista.
uniform vec4 view_world;
uniform vec2 view_size;
uniform vec4 ink : source_color;
// Metros en los que se funde el borde del mundo.
uniform float edge_fade = 4.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 world = view_world.xy + local / view_size * view_world.zw;
	vec2 uv = (world - world_rect.xy) / world_rect.zw;
	vec2 edge = min(world - world_rect.xy, world_rect.xy + world_rect.zw - world);
	float inside = smoothstep(0.0, edge_fade, min(edge.x, edge.y));
	float seen = texture(explored, clamp(uv, 0.0, 1.0)).r;
	vec2 px = TEXTURE_PIXEL_SIZE * 1.5;
	float gx = sketch_luma(texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb) - sketch_luma(texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb);
	float gy = sketch_luma(texture(TEXTURE, UV + vec2(0.0, px.y)).rgb) - sketch_luma(texture(TEXTURE, UV - vec2(0.0, px.y)).rgb);
	vec3 shown = mix(map_sketch(gx, gy, FRAGCOORD.xy), COLOR.rgb, seen);
	COLOR.rgb = mix(ink.rgb, shown, inside);
}
