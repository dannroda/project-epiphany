shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_back, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.3, 0.35, 0.55);
uniform vec4 rim_color : source_color = vec4(1.0, 0.85, 0.8, 1.0);
uniform float rim_power = 2.0;
instance uniform float fade = 1.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), rim_power);
	ALBEDO = mix(tint.rgb, rim_color.rgb, rim);
	ALPHA = clamp(tint.a + rim * 0.4, 0.0, 1.0) * fade;
}
