shader_type canvas_item;
// Niebla del minimapa del overworld: donde todavía no se pasó, la foto se funde en tinta; el mundo termina igual.

// Lo descubierto (GameState.map_revealed): 1 = visto; cubre world_rect.
uniform sampler2D explored : filter_linear, repeat_disable;
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
	float seen = texture(explored, clamp(uv, 0.0, 1.0)).r * smoothstep(0.0, edge_fade, min(edge.x, edge.y));
	COLOR.rgb = mix(ink.rgb, COLOR.rgb, seen);
}
