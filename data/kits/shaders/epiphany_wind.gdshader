shader_type spatial;
// El material de paleta (epiphany.tres) para la vegetación: follaje, paja y flores se mecen con el viento,
// más arriba en su degradé más se mueven (la base queda quieta).

uniform vec4 albedo_color : source_color = vec4(0.72, 0.72, 0.72, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D emission_texture : source_color, hint_default_black, filter_linear_mipmap;
uniform float emission_energy = 1.5;
uniform vec2 wind_direction = vec2(1.0, 0.35);
uniform float wind_strength = 0.07;
uniform float wind_speed = 1.4;
uniform float wave_length = 9.0;

const float COLS = 8.0;
const float ROWS = 4.0;
const float MARGIN = 0.06;

float sway_weight(vec2 uv) {
	int swatch = int(floor(uv.y * ROWS) * COLS + floor(uv.x * COLS));
	// follaje, flor_amarilla, flor_rosa, blanco, paja
	if (swatch != 1 && swatch != 21 && swatch != 22 && swatch != 24 && swatch != 25) {
		return 0.0;
	}
	return clamp((1.0 - fract(uv.y * ROWS) - MARGIN) / (1.0 - 2.0 * MARGIN), 0.0, 1.0);
}

void vertex() {
	float weight = sway_weight(UV);
	if (weight > 0.0) {
		vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec2 dir = normalize(wind_direction);
		float phase = TIME * wind_speed - dot(world.xz, dir) * 6.2832 / wave_length;
		float gust = 0.6 + 0.4 * sin(phase * 0.37);
		float push = (sin(phase) * 0.7 + sin(phase * 2.3 + world.x) * 0.3) * gust * wind_strength * weight;
		VERTEX += (inverse(MODEL_MATRIX) * vec4(dir.x * push, 0.0, dir.y * push, 0.0)).xyz;
	}
}

void fragment() {
	ALBEDO = albedo_color.rgb * texture(albedo_texture, UV).rgb;
	ROUGHNESS = 1.0;
	EMISSION = texture(emission_texture, UV).rgb * emission_energy;
}
