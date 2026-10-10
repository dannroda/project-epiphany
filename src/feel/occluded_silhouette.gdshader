shader_type spatial;
// Silueta del player donde algo lo tapa: se dibuja sin prueba de profundidad donde su destello (hit_flash) no marcó
// el stencil, o sea donde no se lo ve. Así el cuerpo no se tapa a sí mismo. Fresnel: brilla en los bordes.
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_back, shadows_disabled, fog_disabled;
stencil_mode read, compare_not_equal, 1;

uniform vec4 color : source_color = vec4(0.851, 0.643, 0.255, 1.0);
uniform float fresnel_power = 2.0;
uniform float core_alpha : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_power);
	ALBEDO = color.rgb;
	ALPHA = color.a * mix(core_alpha, 1.0, fresnel);
}
