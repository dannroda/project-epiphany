// Llama de antorcha a lo LA (como la del visor): un cartel que siempre mira a la cámara, con forma de gota que titila,
// el centro claro y bien brillante para que lo agarre el glow.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 core_color : source_color = vec3(1.0, 0.85, 0.45);
uniform vec3 edge_color : source_color = vec3(1.0, 0.35, 0.05);
uniform float intensity = 8.0;

void vertex() {
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), 1.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(center + right * VERTEX.x * scale.x + vec3(0.0, VERTEX.y * scale.y, 0.0), 1.0);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float phase = dot(NODE_POSITION_WORLD, vec3(3.1, 1.7, 5.3));
	float n = noise(vec2(uv.x * 3.0, uv.y * 2.0 + TIME * 3.0 + phase));
	float y = clamp((uv.y + 1.0) * 0.5, 0.0, 1.0);
	float width = mix(0.05, 0.75, pow(y, 0.7)) * (0.8 + 0.4 * n);
	float shape = 1.0 - smoothstep(width * 0.6, width, abs(uv.x + (n - 0.5) * 0.3 * (1.0 - y)));
	shape *= smoothstep(0.0, 0.25, y) * (1.0 - smoothstep(0.85, 1.0, y));
	float core = shape * smoothstep(0.3, 0.9, y) * (1.0 - smoothstep(0.0, width * 0.5, abs(uv.x)));
	ALBEDO = (edge_color * shape + core_color * core) * intensity;
}
