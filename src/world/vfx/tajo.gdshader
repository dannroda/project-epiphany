// Tajo de la espada: media luna de luz en un PlaneMesh centrado en el personaje, entre el ángulo donde arrancó la hoja
// (`start`) y donde está ahora la punta (`head`), en radianes de atan(x, z) del plano. Junto a la hoja es ancha y blanca;
// hacia atrás se afina, se vuelve azul y el borde de adentro se deshilacha con ruido que corre con el arco (idea de
// "Procedural Cyclic Slash", godotshaders.com, CC0, sin sus texturas). `fade` 0..1 la apaga.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.5, 0.92, 1.0, 1.0);
uniform vec4 deep : source_color = vec4(0.1, 0.3, 0.95, 1.0);
uniform float energy = 2.4;
uniform float radius = 0.8;
uniform float thickness = 0.34;
uniform float tail = 2.2;
instance uniform float start = 0.0;
instance uniform float head = 0.0;
instance uniform float fade = 0.0;

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
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q);
	float a = atan(q.x, q.y);
	float sweep = head - start;
	float dir = sweep < 0.0 ? -1.0 : 1.0;
	float back = mod((head - a) * dir + 0.3, TAU) - 0.3;
	float reach = min(abs(sweep), tail);
	float t = clamp(back / max(reach, 0.001), 0.0, 1.0);
	float inside = step(0.0, back) * step(back, reach);
	float rough = noise(vec2(back * 5.0, r * 9.0)) * 0.65 + noise(vec2(back * 13.0, r * 21.0)) * 0.35;
	float w = thickness * (1.0 - t * 0.8) * (0.55 + 0.6 * rough);
	float outer = 1.0 - smoothstep(radius - 0.01, radius + 0.02, r);
	float body = smoothstep(radius - w, radius - w * 0.55, r) * outer;
	float rim = smoothstep(radius - 0.08, radius - 0.015, r) * outer;
	float hot = (1.0 - t) * (1.0 - t);
	vec3 tint = mix(deep.rgb, color.rgb, 1.0 - t * 0.8);
	tint = mix(tint, vec3(1.0), clamp(rim * 0.8 + hot * body * 0.5, 0.0, 1.0));
	ALBEDO = tint * energy;
	ALPHA = clamp(body * (0.35 + 0.65 * hot) * (0.7 + 0.5 * rough) + rim * (1.0 - t * 0.7), 0.0, 1.0) * inside * (1.0 - fade);
}
