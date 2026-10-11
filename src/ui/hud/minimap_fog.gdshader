shader_type canvas_item;
// Niebla del minimapa del overworld: lo de fuera de una elipse alrededor del player y las zonas sin explorar se
// disuelven en tinta con el mismo dither que el agujero de las paredes (11.40), pero al revés.

// 1 donde está explorado (o fuera de toda zona), 0 en zonas sin visitar y en el borde; cubre world_rect.
uniform sampler2D explored : filter_linear, repeat_disable;
uniform vec4 world_rect;
// Qué rectángulo del mundo (x, z, ancho, alto) muestra la vista.
uniform vec4 view_world;
uniform vec2 view_size;
uniform vec4 ink : source_color;
// Desde qué fracción del radio empieza a disolverse.
uniform float fade_from = 0.62;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 from_center = (local - view_size * 0.5) / (view_size * 0.5);
	float ring = 1.0 - smoothstep(fade_from, 1.0, length(from_center));
	vec2 world = view_world.xy + local / view_size * view_world.zw;
	vec2 uv = (world - world_rect.xy) / world_rect.zw;
	float seen = texture(explored, clamp(uv, 0.0, 1.0)).r;
	float dither = fract(sin(dot(floor(FRAGCOORD.xy * 0.5), vec2(12.9898, 78.233))) * 43758.5453);
	if (ring * seen < 0.15 + 0.7 * dither) {
		COLOR = vec4(ink.rgb, COLOR.a);
	}
}
