shader_type spatial;
// El material de paleta (epiphany.tres) para las paredes del overworld, con el agujero alrededor del player.

#include "player_hole.gdshaderinc"
#include "wind.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(0.72, 0.72, 0.72, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D emission_texture : source_color, hint_default_black, filter_linear_mipmap;
uniform float emission_energy = 1.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX += wind_offset(UV, world_pos, MODEL_MATRIX);
}

void fragment() {
	if (in_player_hole(world_pos, VERTEX, VIEW_MATRIX, CAMERA_POSITION_WORLD, FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = albedo_color.rgb * texture(albedo_texture, UV).rgb;
	ROUGHNESS = 1.0;
	EMISSION = texture(emission_texture, UV).rgb * emission_energy;
}
