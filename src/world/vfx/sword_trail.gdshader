
shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 deep : source_color = vec4(0.1, 0.3, 0.95, 1.0);
uniform float energy = 1.8;
uniform float fade = 0.0;

void vertex() {
	// Billboarding code for trails
	// CUSTOM0 contains the tangent of the trail and the width
	if (dot(CUSTOM0.xyz, CUSTOM0.xyz) > 0.0) {
		vec3 p = (inverse(MODELVIEW_MATRIX) * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		p = VERTEX - p;
		vec3 t = CUSTOM0.xyz;
		vec3 binormal = normalize(cross(p, t));
		vec3 normal = normalize(cross(t, binormal));
		vec3 tangent = normalize(cross(binormal, normal));
		VERTEX += CUSTOM0.w * binormal;
		NORMAL = normal;
		TANGENT = tangent;
		BINORMAL = binormal;
	}
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

// UV.x: 0 en la hoja, 1 al final de la cola. UV.y: 0 en el mango, 1 en la punta.
// Media luna: ancha y blanca junto a la hoja, se afina hacia la punta y se vuelve azul en la cola; el borde de adentro
// se deshilacha con ruido que corre. `fade` apaga lo que queda al dejar de emitir (Trail3D no lo desvanece solo).
void fragment() {
	float head = 1.0 - UV.x;
	float across = UV.y;
	float rough = noise(vec2(UV.x * 7.0 + TIME * 3.0, across * 6.0)) * 0.65 + noise(vec2(UV.x * 17.0 + TIME * 5.0, across * 14.0)) * 0.35;
	float inner = mix(0.92, 0.12, pow(head, 1.5)) + (rough - 0.5) * 0.3;
	float body = smoothstep(inner, inner + 0.2, across);
	float rim = smoothstep(0.8, 0.97, across) * (0.3 + 0.7 * head);
	float hot = head * head;
	vec3 tint = mix(deep.rgb, COLOR.rgb, 0.2 + 0.8 * head);
	tint = mix(tint, vec3(1.0), clamp(rim * 0.6 + hot * body * 0.15, 0.0, 1.0));
	ALBEDO = tint * energy;
	ALPHA = clamp(body * (0.3 + 0.7 * hot) * (0.7 + 0.5 * rough) + rim * head, 0.0, 1.0) * COLOR.a * (1.0 - fade);
}
