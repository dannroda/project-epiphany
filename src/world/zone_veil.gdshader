shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
// Velo de una zona sin ver; al abrirse se disuelve con dither desde reveal_center.

uniform vec4 ink : source_color;
uniform float edge = 2.0;
instance uniform vec2 reveal_center;
instance uniform float reveal_radius = 0.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dither = fract(sin(dot(floor(FRAGCOORD.xy * 0.5), vec2(12.9898, 78.233))) * 43758.5453);
	if (distance(world.xz, reveal_center) < reveal_radius - edge * dither) {
		discard;
	}
	ALBEDO = ink.rgb;
}
