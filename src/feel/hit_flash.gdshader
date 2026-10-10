shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
// Marca dónde se ve la entidad (lo lee la silueta del player detrás de las paredes).
stencil_mode write, compare_always, 1;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0);

void fragment() {
	ALBEDO = color.rgb * flash;
}
