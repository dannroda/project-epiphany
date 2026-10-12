// El mapa sin explorar: la foto como boceto en tinta sobre pergamino (bordes de la luminancia).

const vec3 SKETCH_PAPER = vec3(0.80, 0.72, 0.56);
const vec3 SKETCH_INK = vec3(0.42, 0.31, 0.19);
const float SKETCH_INK_STRENGTH = 0.75;

float sketch_luma(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

float sketch_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// gx, gy: diferencias de luminancia entre vecinos de la foto.
vec3 map_sketch(float gx, float gy, vec2 frag) {
	float edge = smoothstep(0.012, 0.05, length(vec2(gx, gy)));
	vec3 color = SKETCH_PAPER * (0.94 + 0.06 * sketch_hash(floor(frag * 0.5)));
	return mix(color, SKETCH_INK, edge * SKETCH_INK_STRENGTH);
}
