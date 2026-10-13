shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

// Rectángulos XZ (x0, z0, x1, z1) en mundo: adentro de inner no oscurece, en outer ya es negro. El velo va más alto
// (sobre los pilares) y mide cada píxel donde está lo que tapa.
uniform vec4 inner;
uniform vec4 outer;
// Fuera de limit (donde empieza la máscara de la cámara) no oscurece: es de otra sala.
uniform vec4 limit;
uniform float plane_y;
// Lo que queda fuera del piso y no está a la altura de la cresta (pasillos de las puertas, pilares) ya es negro a hole_fade del piso.
uniform vec4 floor_rect;
uniform float hole_fade = 1.2;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

// Borde irregular: el oscurecido avanza y retrocede hasta wobble (en fracción del recorrido) por esta escala en metros.
uniform float wobble = 0.25;
uniform float wobble_scale = 1.3;

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(depth_texture, SCREEN_UV).r, 1.0);
	vec3 seen = (INV_VIEW_MATRIX * vec4(view.xyz / view.w, 1.0)).xyz;
	vec2 p = seen.xz;
	vec2 before = max(inner.xy - p, 0.0) / max(inner.xy - outer.xy, 0.001);
	vec2 after = max(p - inner.zw, 0.0) / max(outer.zw - inner.zw, 0.001);
	float a = clamp(max(max(before.x, before.y), max(after.x, after.y)), 0.0, 1.0);
	if (abs(seen.y - plane_y) > 0.3) {
		vec2 out_before = max(floor_rect.xy - seen.xz, 0.0);
		vec2 out_after = max(seen.xz - floor_rect.zw, 0.0);
		a = max(a, clamp(max(max(out_before.x, out_before.y), max(out_after.x, out_after.y)) / hole_fade, 0.0, 1.0));
	}
	float n = noise(p / wobble_scale) * 0.65 + noise(p / wobble_scale * 2.7) * 0.35;
	a = clamp(a * (1.0 + wobble) - wobble * n, 0.0, 1.0);
	ALBEDO = vec3(0.0);
	bool inside = all(greaterThan(p, limit.xy)) && all(lessThan(p, limit.zw));
	ALPHA = inside ? a * a * (3.0 - 2.0 * a) : 0.0;
}
