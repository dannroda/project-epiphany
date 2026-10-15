shader_type canvas_item;
// Fondo del título: el overworld en vivo desenfocado, oscurecido y con viñeta para que el logo y el menú se lean.

uniform float radius : hint_range(0.0, 8.0) = 4.0;
uniform float dim : hint_range(0.0, 1.0) = 0.55;
uniform float vignette : hint_range(0.0, 1.0) = 0.6;
uniform vec3 tint : source_color = vec3(0.82, 0.86, 1.0);

const vec2 TAPS[12] = vec2[](vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457), vec2(-0.203, 0.621),
	vec2(0.962, -0.195), vec2(0.473, -0.480), vec2(0.519, 0.767), vec2(0.185, -0.893),
	vec2(0.507, 0.064), vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598));

void fragment() {
	vec3 sum = texture(TEXTURE, UV).rgb;
	for (int i = 0; i < 12; i++) {
		sum += texture(TEXTURE, UV + TAPS[i] * TEXTURE_PIXEL_SIZE * radius).rgb;
	}
	vec3 color = sum / 13.0 * tint * (1.0 - dim);
	vec2 d = UV - 0.5;
	color *= 1.0 - vignette * smoothstep(0.2, 0.75, length(d * vec2(1.0, 0.8)));
	COLOR = vec4(color, COLOR.a);
}
