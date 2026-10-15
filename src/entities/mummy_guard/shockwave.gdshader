shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
// Onda del aterrizaje: una ola de energía entera (sin huecos: no hay por dónde pasar) que se levanta del piso y rompe
// hacia afuera, con la cresta más brillante, en los colores de quien la larga (`glow` la ola, `core` la cresta). Va
// en un cilindro abierto de radio 1 y alto 1 que se escala al radio; el alto lo da `height`.

uniform float height = 1.0;
uniform float energy = 1.5;
instance uniform vec4 core: source_color = vec4(1.0, 0.8, 0.4, 1.0);
instance uniform vec4 glow: source_color = vec4(0.95, 0.25, 0.08, 1.0);
instance uniform float radius = 1.0;
instance uniform float width = 0.9;
instance uniform float fade = 1.0;

varying float along;
varying float lift;
varying vec2 around;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	float t = 1.0 - (VERTEX.y + 0.5);
	vec2 dir = normalize(VERTEX.xz);
	float swell = 1.0 + 0.3 * (noise(dir * 3.0 + vec2(TIME * 1.4, 0.0)) - 0.5);
	float h = height * mix(0.35, 1.0, fade) * swell;
	float off;
	float y;
	if (t < 0.6) {
		float s = t / 0.6;
		off = mix(-0.5, 0.0, s) * width;
		y = h * pow(s, 1.6);
	} else if (t < 0.85) {
		float phi = mix(PI * 0.5, -PI * 0.3, (t - 0.6) / 0.25);
		off = 0.45 * width * cos(phi);
		y = h * (0.65 + 0.35 * sin(phi));
	} else {
		float s = (t - 0.85) / 0.15;
		off = mix(0.45 * cos(-PI * 0.3), 0.3, s) * width;
		y = h * (0.65 + 0.35 * sin(-PI * 0.3)) * (1.0 - s);
	}
	VERTEX.xz = dir * (1.0 + off / max(radius, 0.05));
	VERTEX.y = max(y, 0.0);
	along = t;
	lift = clamp(y / max(h, 0.001), 0.0, 1.0);
	around = dir;
}

void fragment() {
	float a = atan(around.y, around.x);
	float flow = noise(vec2(a * 18.0, along * 5.0 - TIME * 3.0));
	float crest = 1.0 - smoothstep(0.0, 0.08, abs(along - 0.66 + 0.03 * (flow - 0.5)));
	float foam = step(0.8, noise(vec2(a * 60.0, along * 14.0 - TIME * 5.0))) * smoothstep(0.5, 0.65, along) * (1.0 - smoothstep(0.75, 0.85, along));
	float body = along < 0.6 ? mix(0.05, 0.55, smoothstep(0.0, 0.6, along)) : mix(0.75, 0.2, smoothstep(0.7, 1.0, along));
	vec3 color = mix(glow.rgb, core.rgb, smoothstep(0.5, 1.0, lift) * 0.7);
	color = mix(color, mix(core.rgb, vec3(1.0), 0.5), max(crest, foam));
	ALBEDO = color * energy * mix(0.85, 1.15, flow);
	ALPHA = clamp(body + crest * 0.6 + foam * 0.5 + 0.15 * (flow - 0.5), 0.0, 1.0) * fade;
}
