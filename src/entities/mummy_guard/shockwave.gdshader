shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
// Onda del aterrizaje: un anillo que brilla y dobla lo que tiene abajo. El plano mide 2 (radio 1) y se escala al radio.

uniform sampler2D screen: hint_screen_texture, filter_linear_mipmap;
uniform vec4 core: source_color = vec4(1.0, 0.93, 0.7, 1.0);
uniform vec4 glow: source_color = vec4(1.0, 0.55, 0.15, 1.0);
uniform float bend = 0.035;
instance uniform float radius = 1.0;
instance uniform float width = 0.9;
instance uniform float fade = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float half_band = width * 0.5 / max(radius, 0.01);
	float edge = 1.0 - half_band;
	float d = (r - edge) / half_band;
	float band = 1.0 - smoothstep(0.0, 1.0, abs(d));
	float lead = smoothstep(-1.0, 0.0, d) * (1.0 - smoothstep(0.0, 0.35, d));
	vec2 push = normalize(p + vec2(0.0001)) * band * bend * fade;
	vec3 below = texture(screen, SCREEN_UV - push).rgb;
	ALBEDO = below + glow.rgb * band * 1.4 * fade + core.rgb * lead * 1.6 * fade;
	ALPHA = clamp(band * 1.5, 0.0, 1.0) * (r < 1.0 ? 1.0 : 0.0);
}
