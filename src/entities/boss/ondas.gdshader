// Ondas que salen de un óvalo que brilla (el ojo del lomo de las manos del jefe, las orejeras): aros que crecen desde
// `inner` hasta el borde del quad y se apagan. El quad da la forma: uno ancho, ondas ovaladas.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.45, 0.95, 1.0, 1.0);
uniform float energy = 1.6;
uniform float inner : hint_range(0.0, 1.0) = 0.38;
uniform float speed = 0.55;
uniform float waves = 3.0;
uniform float width = 0.07;

void fragment() {
	float r = length((UV - 0.5) * 2.0);
	float light = 0.0;
	for (float i = 0.0; i < waves; i += 1.0) {
		float phase = fract(TIME * speed + i / waves);
		float radius = mix(inner, 1.0, phase);
		light += smoothstep(width, 0.0, abs(r - radius)) * (1.0 - phase) * smoothstep(0.0, 0.15, phase);
	}
	ALBEDO = color.rgb * energy;
	ALPHA = clamp(light, 0.0, 1.0) * color.a;
}
