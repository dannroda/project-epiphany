shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
// Luz del teletransporte (rayo y esfera): blanca en el centro y del color del player en el borde.

uniform vec4 color : source_color = vec4(0.85, 0.64, 0.25, 1.0);
uniform float energy = 1.6;
instance uniform float alpha = 1.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.2);
	ALBEDO = mix(vec3(1.0), color.rgb * 1.3, smoothstep(0.0, 0.45, rim)) * energy * alpha * (1.0 - rim * 0.3);
}
