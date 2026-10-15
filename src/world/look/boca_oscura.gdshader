// Profundidad de una entrada del overworld, como la viñeta de las salas: en el borde de la boca se ve lo de alrededor
// desenfocado, y hacia adentro se va oscureciendo hasta el fondo. Va en un QuadMesh delante del hueco negro; la boca es
// un trapecio (half_bottom abajo, half_top arriba, height de alto, en metros desde el centro del piso) con arco opcional.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform vec2 size = vec2(2.6, 3.0);
uniform float half_bottom = 1.0;
uniform float half_top = 0.8;
uniform float height = 2.6;
uniform float arch = 0.0;
uniform float feather = 0.22;
uniform float depth = 1.1;
uniform float floor_soft = 0.35;
uniform float blur = 2.5;
uniform vec3 deep : source_color = vec3(0.02, 0.015, 0.03);

float inside(vec2 p) {
	float half_w = mix(half_bottom, half_top, clamp(p.y / height, 0.0, 1.0));
	float d = min(half_w - abs(p.x), height - p.y);
	if (arch > 0.0 && p.y > height - arch) {
		d = min(half_w - abs(p.x), arch - length(p - vec2(0.0, height - arch)));
	}
	return d;
}

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * size.x, (1.0 - UV.y) * size.y);
	float d = inside(p);
	float floor_fade = smoothstep(0.0, floor_soft, p.y);
	vec3 around = textureLod(screen, SCREEN_UV, blur).rgb;
	float dark = smoothstep(0.0, depth, d) * mix(0.55, 1.0, floor_fade);
	ALBEDO = mix(around * 0.8, deep, dark);
	ALPHA = smoothstep(-feather, feather * 0.5, d);
}
