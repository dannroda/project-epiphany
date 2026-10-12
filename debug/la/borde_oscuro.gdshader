shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

// Rectángulos XZ (x0, z0, x1, z1) en mundo, a la altura plane_y de la cresta: adentro de inner no oscurece, en outer
// ya es negro. El velo va más alto (sobre los pilares) y mide cada píxel donde su rayo cruza esa altura.
uniform vec4 inner;
uniform vec4 outer;
// Fuera de limit (donde empieza la máscara de la cámara) no oscurece: es de otra sala.
uniform vec4 limit;
uniform float plane_y;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 to_eye = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	vec2 p = (world_pos + to_eye * (plane_y - world_pos.y) / to_eye.y).xz;
	vec2 before = max(inner.xy - p, 0.0) / max(inner.xy - outer.xy, 0.001);
	vec2 after = max(p - inner.zw, 0.0) / max(outer.zw - inner.zw, 0.001);
	float a = clamp(max(max(before.x, before.y), max(after.x, after.y)), 0.0, 1.0);
	ALBEDO = vec3(0.0);
	bool inside = all(greaterThan(p, limit.xy)) && all(lessThan(p, limit.zw));
	ALPHA = inside ? smoothstep(0.0, 1.0, a) : 0.0;
}
