// Cel shading de dos tonos (estilo Wind Waker) para los shaders spatial: el fragment() pone toon_shade (el color en
// sombra) y este light() corta la luz direccional en luz/sombra. Las luces puntuales y spot (antorchas, cáusticas)
// suman sin corte, así su patrón no se umbraliza.

uniform float toon_threshold : hint_range(-1.0, 1.0) = 0.05;
uniform float toon_softness : hint_range(0.0, 0.2) = 0.02;
// Las sombras proyectadas del sol pueden tener opacidad parcial: por debajo de este valor de atenuación es sombra.
uniform float toon_shadow_cut : hint_range(0.0, 1.0) = 0.9;
uniform float toon_lit_energy : hint_range(0.0, 2.0) = 0.8;
uniform float toon_shade_energy : hint_range(0.0, 2.0) = 0.85;
uniform float toon_rim : hint_range(0.0, 1.0) = 0.0;

varying vec3 toon_shade;

const vec2 TOON_PALETTE_GRID = vec2(8.0, 4.0);
const float TOON_PALETTE_MARGIN = 0.06;

// Cada tira de la paleta va de claro (arriba) a oscuro (abajo): la sombra es el color multiplicado por la relación
// oscuro/claro de su tira, así oscurece con el matiz propio de la tira aunque la pieza esté pintada cerca del oscuro.
vec3 toon_palette_shade(sampler2D palette, vec2 uv, vec3 albedo, float depth) {
	vec2 cell = floor(uv * TOON_PALETTE_GRID);
	float x = fract(uv.x * TOON_PALETTE_GRID.x);
	vec3 light_end = texture(palette, (cell + vec2(x, TOON_PALETTE_MARGIN)) / TOON_PALETTE_GRID).rgb;
	vec3 dark_end = texture(palette, (cell + vec2(x, 1.0 - TOON_PALETTE_MARGIN)) / TOON_PALETTE_GRID).rgb;
	return albedo * mix(vec3(1.0), dark_end / max(light_end, vec3(0.001)), depth);
}

// Sin paleta (triplanar): sombra más oscura y fría.
vec3 toon_tint_shade(vec3 albedo) {
	return albedo * vec3(0.5, 0.52, 0.68);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = smoothstep(toon_threshold - toon_softness, toon_threshold + toon_softness, ndl)
				* smoothstep(toon_shadow_cut - toon_softness, toon_shadow_cut + toon_softness, ATTENUATION);
		vec3 ratio = toon_shade / max(ALBEDO, vec3(0.001));
		vec3 band = mix(ratio * toon_shade_energy, vec3(toon_lit_energy), lit);
		float rim = toon_rim * lit * smoothstep(0.62, 0.68, 1.0 - dot(NORMAL, VIEW));
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * (band + rim);
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * ATTENUATION * smoothstep(0.0, 0.15, ndl);
	}
}
