shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
// Onda del aterrizaje: un anillo de fuego entero (sin huecos: no hay por dónde pasar) con lenguas que titilan y doblan
// lo que tienen abajo, en los colores de quien la larga (`glow` el fuego, `core` lo más caliente). El plano mide 2
// (radio 1) y se escala al radio.

uniform sampler2D screen: hint_screen_texture, filter_linear_mipmap;
uniform float bend = 0.03;
uniform float energy = 1.8;
instance uniform vec4 core: source_color = vec4(1.0, 0.8, 0.4, 1.0);
instance uniform vec4 glow: source_color = vec4(0.95, 0.25, 0.08, 1.0);
instance uniform float radius = 1.0;
instance uniform float width = 0.9;
instance uniform float fade = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 dir = p / max(r, 0.0001);
	float half_band = width * 0.5 / max(radius, 0.01);
	float d = (r - (1.0 - half_band)) / half_band;
	float tongue = noise(dir * 5.0 + vec2(0.0, -TIME * 2.5));
	float flick = noise(dir * 11.0 + vec2(TIME * 6.0, 3.0));
	float lick = d + 0.5 * (tongue - 0.5) + 0.25 * (flick - 0.5);
	float body = 1.0 - smoothstep(0.0, mix(0.55, 1.2, tongue), abs(lick));
	float pulse = mix(0.65, 1.0, noise(dir * 4.0 + vec2(TIME * 1.3, 7.0)));
	float streaks = mix(0.55, 1.0, noise(vec2(atan(p.y, p.x) * 14.0, r * 6.0 - TIME * 4.0)));
	float fire = max(body, 0.45 * (1.0 - smoothstep(0.0, 0.7, abs(d)))) * pulse * streaks * fade;
	vec3 color = mix(glow.rgb, core.rgb, smoothstep(0.45, 0.95, fire));
	vec2 push = dir * fire * bend;
	vec3 below = texture(screen, SCREEN_UV - push).rgb;
	ALBEDO = below + color * fire * energy;
	ALPHA = clamp(fire * 1.6, 0.0, 1.0) * (r < 1.0 ? 1.0 : 0.0);
}
