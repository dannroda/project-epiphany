shader_type spatial;

uniform sampler2D albedo_texture : source_color;

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	// Invert the RGB values and keep alpha intact
	ALBEDO = vec3(1.0) - tex_color.rgb;
}
