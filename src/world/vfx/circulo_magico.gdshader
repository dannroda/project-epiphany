// Círculo mágico en el piso, sin texturas: anillos, marcas y runas que giran y una chakana en el centro que gira al
// revés, todo latiendo. Va en un PlaneMesh; el color lo pone cada uno (portal dorado, de viaje celeste, etc.).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.95, 0.7, 0.3, 1.0);
uniform float energy = 2.0;
uniform float spin = 0.05;

float ring(float r, float at, float width) {
	return smoothstep(width, 0.0, abs(r - at));
}

float box(vec2 p, vec2 half_size) {
	vec2 d = abs(p) - half_size;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

vec2 rotate(vec2 p, float a) {
	return mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * p;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float turn = atan(p.y, p.x) / TAU + 0.5;
	float light = ring(r, 0.93, 0.025) + ring(r, 0.8, 0.012) + ring(r, 0.44, 0.012) * 0.8;
	float ticks = step(0.55, fract((turn + TIME * spin) * 36.0)) * step(0.82, r) * step(r, 0.9);
	float runes = step(0.35, fract((turn - TIME * spin * 0.6) * 12.0)) * step(fract((turn - TIME * spin * 0.6) * 48.0), 0.6);
	runes *= smoothstep(0.015, 0.0, abs(r - 0.62)) + step(0.58, r) * step(r, 0.66) * 0.35;
	vec2 q = rotate(p, -TIME * spin * 4.0);
	float cross_shape = min(min(box(q, vec2(0.33, 0.11)), box(q, vec2(0.22, 0.22))), box(q, vec2(0.11, 0.33)));
	float chakana = smoothstep(0.018, 0.0, abs(cross_shape)) + smoothstep(0.03, 0.0, abs(length(q) - 0.06));
	float fill = smoothstep(0.95, 0.2, r) * 0.12;
	float pulse = 0.8 + 0.2 * sin(TIME * 2.4);
	ALBEDO = color.rgb * energy;
	ALPHA = clamp((light + ticks * 0.7 + runes * 0.6 + chakana + fill) * pulse, 0.0, 1.0) * color.a * step(r, 1.0);
}
