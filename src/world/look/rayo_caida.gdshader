// Haz de luz que baja por un hueco al piso de abajo: una lámina que mira a la cámara, más fuerte arriba y suave en los costados.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.88, 0.66);
uniform float strength = 0.5;

void vertex() {
	vec3 up = normalize(MODEL_MATRIX[1].xyz);
	vec3 side = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side * length(MODEL_MATRIX[0].xyz), 0.0), MODEL_MATRIX[1], vec4(cross(side, up), 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float across = sin(UV.x * PI);
	float down = smoothstep(0.0, 0.15, UV.y) * (1.0 - UV.y);
	ALBEDO = color * strength * across * across * down;
}
