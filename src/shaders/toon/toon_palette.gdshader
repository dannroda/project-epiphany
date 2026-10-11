shader_type spatial;
// El material de paleta (como data/kits/materials/epiphany.tres) con cel shading.

#include "toon.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(0.72, 0.72, 0.72, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D emission_texture : source_color, hint_default_black, filter_linear_mipmap;
uniform float emission_energy = 1.5;
uniform float shade_depth : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	ALBEDO = albedo_color.rgb * texture(albedo_texture, UV).rgb;
	toon_shade = toon_palette_shade(albedo_texture, UV, ALBEDO, shade_depth);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = texture(emission_texture, UV).rgb * emission_energy;
}
