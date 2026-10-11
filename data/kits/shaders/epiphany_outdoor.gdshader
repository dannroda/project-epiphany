shader_type spatial;
// El material de paleta (epiphany.tres) para lo de afuera: con sombras de nubes y viento (wind.gdshaderinc).

#include "cloud_shadows.gdshaderinc"
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
	ALBEDO = albedo_color.rgb * texture(albedo_texture, UV).rgb * cloud_shade(world_pos, TIME);
	ROUGHNESS = 1.0;
	EMISSION = texture(emission_texture, UV).rgb * emission_energy;
}
