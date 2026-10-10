shader_type spatial;
// Pasada 3: deja el stencil en 0 en toda la huella de la esfera para la luz siguiente.
render_mode unshaded, cull_back, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
stencil_mode write, compare_always, 0;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
