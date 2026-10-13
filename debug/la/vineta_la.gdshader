// Viñeta como la de LA (calibrada en el visor de LA): solo oscurece los costados, crece lineal con la distancia al centro.
shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float inner = 0.28;
uniform float power = 1.2;

void fragment() {
	float d = abs(UV.x - 0.5) * 2.0;
	float dark = pow(clamp((d - inner) / (0.95 - inner), 0.0, 1.0), power) * strength;
	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - pow(1.0 - dark, 1.0 / 2.2));
}
