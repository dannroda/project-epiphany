shader_type spatial;
// Cambia celdas de color de un atlas de franjas con degradé (la paleta de assets/epiphany) por otra celda, conservando el degradé.
// Las celdas se cuentan en la grilla `grid` (8 × 4). Hasta 4 celdas claras y 4 oscuras;
// las oscuras toman la celda destino multiplicada por `dark_factor`. Las que sobran van en (-1, -1).

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D emission_texture : source_color, filter_linear_mipmap, hint_default_black;
uniform float emission_energy = 1.5;
uniform vec2 grid = vec2(8.0, 4.0);
uniform ivec2 target_cell = ivec2(4, 1);
uniform ivec2 light_cells[4];
uniform ivec2 dark_cells[4];
uniform float dark_factor = 0.6;

void fragment() {
	vec2 cell_f = floor(UV * grid);
	ivec2 cell = ivec2(cell_f);
	vec2 local = UV * grid - cell_f;
	float shade = 1.0;
	bool remap = false;
	for (int i = 0; i < 4; i++) {
		if (cell == light_cells[i]) {
			remap = true;
		}
		if (cell == dark_cells[i]) {
			remap = true;
			shade = dark_factor;
		}
	}
	vec2 uv = UV;
	if (remap) {
		uv = (vec2(target_cell) + vec2(0.5, local.y)) / grid;
	}
	ALBEDO = texture(albedo_texture, uv).rgb * tint.rgb * shade;
	EMISSION = texture(emission_texture, UV).rgb * emission_energy;
	ROUGHNESS = 1.0;
	SPECULAR = 0.3;
}
