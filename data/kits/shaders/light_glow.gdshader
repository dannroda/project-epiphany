shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
// Halo de los haces de luz (material_overlay): infla la malla en metros de mundo, brilla al centro y se apaga en el
// borde, con un titileo leve.

uniform vec4 color : source_color = vec4(1.0, 0.92, 0.6, 1.0);
uniform float grow = 0.12;
uniform float strength = 0.55;

varying float shimmer;

void vertex() {
	vec3 normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(normal * grow, 0.0)).xyz;
	shimmer = 0.85 + 0.15 * sin(TIME * 7.0 + dot(world, vec3(2.3, 1.7, 2.9)));
}

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	ALBEDO = color.rgb * strength * shimmer * facing * facing;
}
