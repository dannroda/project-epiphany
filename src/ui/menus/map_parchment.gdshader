shader_type canvas_item;
// Zona sin explorar del mapa: la foto del nivel como boceto en tinta sobre pergamino.

uniform sampler2D map_texture : filter_linear;
// Qué parte de la foto cubre esta zona (posición y tamaño en UV).
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 paper : source_color = vec4(0.80, 0.72, 0.56, 1.0);
uniform vec4 ink : source_color = vec4(0.42, 0.31, 0.19, 1.0);
uniform float ink_strength = 0.75;

float luma(vec2 uv) {
	return dot(texture(map_texture, uv).rgb, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = uv_rect.xy + UV * uv_rect.zw;
	vec2 px = 1.5 / vec2(textureSize(map_texture, 0));
	float gx = luma(uv + vec2(px.x, 0.0)) - luma(uv - vec2(px.x, 0.0));
	float gy = luma(uv + vec2(0.0, px.y)) - luma(uv - vec2(0.0, px.y));
	float edge = smoothstep(0.012, 0.05, length(vec2(gx, gy)));
	float grain = hash(floor(FRAGCOORD.xy * 0.5));
	vec2 border = min(UV, 1.0 - UV) * 8.0;
	float burn = 1.0 - clamp(min(border.x, border.y), 0.0, 1.0);
	vec3 color = paper.rgb * (0.94 + 0.06 * grain);
	color = mix(color, ink.rgb, edge * ink_strength);
	color = mix(color, ink.rgb, burn * 0.35);
	COLOR = vec4(color, 1.0);
}
