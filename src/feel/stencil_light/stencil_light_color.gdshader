shader_type spatial;
// Pasada 2: la cara de atrás, donde la escena queda delante de ella y no está marcada (o sea, adentro), multiplica.
render_mode unshaded, blend_mul, cull_front, depth_draw_never, depth_test_inverted, shadows_disabled, fog_disabled;
stencil_mode read, compare_not_equal, 2;

uniform vec4 color : source_color = vec4(1.0);

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
