// Pulso del óvalo del lomo de la mano: cada partícula es un aro con la forma del óvalo que sube, se abre y se apaga
// (INSTANCE_CUSTOM.y es la edad). `stun` lo vuelve un aro que tiembla, titila y se blanquea.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.45, 0.95, 1.0, 1.0);
uniform float energy = 2.6;
uniform float stun : hint_range(0.0, 1.0) = 0.0;

varying float age;
varying float seed;

void vertex() {
	age = INSTANCE_CUSTOM.y;
	seed = float(INSTANCE_ID) * 7.31;
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float wobble = stun * sin(atan(q.y, q.x) * 5.0 + TIME * 23.0 + seed) * 0.09;
	float r = length(q) + wobble;
	float radius = mix(0.5, 0.9, age);
	float width = mix(0.22, 0.07, age);
	float ring = smoothstep(width, 0.0, abs(r - radius));
	float fill = (1.0 - smoothstep(0.0, radius, r)) * 0.3;
	float fade = (1.0 - age) * (1.0 - age) * smoothstep(0.0, 0.08, age);
	float flicker = mix(1.0, step(0.45, fract(sin(floor(TIME * 22.0) + seed) * 43758.5453)), stun);
	ALBEDO = mix(color.rgb, vec3(1.0), stun * 0.35) * energy;
	ALPHA = clamp((ring + fill) * fade * flicker, 0.0, 1.0) * color.a;
}
