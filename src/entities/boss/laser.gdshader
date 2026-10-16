shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
// Rayo del ojo, en la línea de la onda de energía (mummy_guard/shockwave.gdshader) pero rojo: un núcleo casi blanco
// que corre hacia la punta, el halo rojo que late y se ensancha a tirones, y chispas que viajan por el haz.
// Va en un cilindro de alto 1 estirado en Y hasta el piso; con `disc` es la quemadura donde pega (cilindro chato).

uniform vec4 core: source_color = vec4(1.0, 0.9, 0.8, 1.0);
uniform vec4 glow: source_color = vec4(1.0, 0.06, 0.04, 1.0);
uniform float energy = 2.6;
uniform float speed = 18.0;
uniform bool disc = false;
uniform float disc_radius = 0.7;

varying float dist;
varying vec2 local;

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
	local = VERTEX.xz;
	dist = 0.0;
	if (!disc) {
		dist = (VERTEX.y + 0.5) * length(MODEL_MATRIX[1].xyz);
		float swell = 1.0 + 0.45 * (noise(vec2(dist * 2.5 - TIME * speed, 0.0)) - 0.5) + 0.12 * sin(TIME * 55.0);
		VERTEX.xz *= swell;
	}
}

void fragment() {
	float core_amount;
	float sparks;
	float shape;
	float flow;
	if (disc) {
		float r = length(local) / disc_radius;
		float a = atan(local.y, local.x);
		flow = noise(vec2(a * 4.0, r * 6.0 - TIME * speed * 0.6));
		core_amount = 1.0 - smoothstep(0.0, 0.45 + 0.1 * flow, r);
		sparks = step(0.82, noise(vec2(a * 14.0, r * 10.0 - TIME * speed))) * (1.0 - smoothstep(0.6, 0.95, r));
		shape = (1.0 - smoothstep(0.75, 1.0, r)) * (0.45 + 0.35 * flow);
	} else {
		float facing = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
		flow = noise(vec2(dist * 4.0 - TIME * speed, facing * 3.0));
		core_amount = smoothstep(0.74 - 0.12 * flow, 0.98, facing);
		sparks = step(0.8, noise(vec2(dist * 9.0 - TIME * speed * 1.6, facing * 8.0)));
		shape = smoothstep(0.0, 0.3, facing) * (0.6 + 0.4 * flow);
	}
	vec3 color = mix(glow.rgb, core.rgb, max(core_amount, sparks * 0.8));
	ALBEDO = color * energy * mix(0.85, 1.2, flow);
	ALPHA = clamp(shape + core_amount + sparks * 0.5, 0.0, 1.0);
}
