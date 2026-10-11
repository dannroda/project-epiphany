// Viento para los materiales de paleta: con wind_strength > 0, follaje, paja y flores se mecen, más arriba en su
// degradé más se mueven (la base queda quieta).

uniform vec2 wind_direction = vec2(1.0, 0.35);
uniform float wind_strength = 0.0;
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

vec3 wind_offset(vec2 uv, vec3 world, mat4 model) {
	float weight = wind_strength > 0.0 ? sway_weight(uv) : 0.0;
	if (weight <= 0.0) {
		return vec3(0.0);
	}
	vec2 dir = normalize(wind_direction);
	float phase = TIME * wind_speed - dot(world.xz, dir) * 6.2832 / wave_length;
	float gust = 0.6 + 0.4 * sin(phase * 0.37);
	float push = (sin(phase) * 0.7 + sin(phase * 2.3 + world.x) * 0.3) * gust * wind_strength * weight;
	return (inverse(model) * vec4(dir.x * push, 0.0, dir.y * push, 0.0)).xyz;
}
