// Fondo de un hueco que cae al piso de abajo: la sala de abajo desenfocada y oscurecida, como vista de lejos.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float blur = 1.5;
uniform float darken = 0.25;
uniform vec3 tint : source_color = vec3(0.86, 0.9, 1.0);

void fragment() {
	vec3 below = textureLod(screen, SCREEN_UV, blur).rgb;
	ALBEDO = below * darken * tint;
}
