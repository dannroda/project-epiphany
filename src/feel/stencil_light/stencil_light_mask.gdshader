shader_type spatial;
// Pasada 1: la cara de adelante de la esfera marca (ref 2) donde la escena queda delante de ella.
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;
stencil_mode write_depth_fail, compare_always, 2;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
