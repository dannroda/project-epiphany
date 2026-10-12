shader_type canvas_item;
// Foto del overworld en el mapa: boceto donde todavía no se pasó, a color donde sí (GameState.map_revealed).

#include "res://src/ui/map_sketch.gdshaderinc"

uniform sampler2D explored : hint_default_black, filter_linear, repeat_disable;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * 1.5;
	float gx = sketch_luma(texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb) - sketch_luma(texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb);
	float gy = sketch_luma(texture(TEXTURE, UV + vec2(0.0, px.y)).rgb) - sketch_luma(texture(TEXTURE, UV - vec2(0.0, px.y)).rgb);
	float seen = texture(explored, UV).r;
	COLOR.rgb = mix(map_sketch(gx, gy, FRAGCOORD.xy), COLOR.rgb, seen);
}
