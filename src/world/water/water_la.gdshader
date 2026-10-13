// Agua a lo Link's Awakening (Switch), armada desde cero con la receta que dejan ver los nombres de su shader: color
// según la profundidad (poco honda, agua, turbia), dos capas de cáusticas en el fondo que se mueven distinto, dos capas
// de relieve que ondulan, deforman lo que se ve a través y dan el brillo del sol, reflejo con Fresnel y espuma en la
// orilla. Todo en coordenadas de mundo: sin costuras entre piezas.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform vec3 shallow_water_color : source_color = vec3(0.36, 0.86, 0.92);
uniform vec3 water_color : source_color = vec3(0.04, 0.5, 0.74);
uniform vec3 muddy_color : source_color = vec3(0.02, 0.3, 0.5);
// Metros de agua hasta el color de agua y hasta el turbio.
uniform float depth_color_range = 1.2;
uniform float depth_global_range = 4.0;
// Cuánto se ve el fondo a través: 1 = transparente en la orilla.
uniform float clarity = 0.85;

uniform vec3 caustics_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float caustics_strength = 0.7;
// Repeticiones por metro y velocidad de cada capa.
uniform vec2 caustics_scale = vec2(0.55, 0.9);
uniform vec2 caustics_speed = vec2(0.35, -0.5);
// Hasta cuántos metros de agua se ven las cáusticas.
uniform float caustics_depth = 8.0;

uniform float bump_scale = 0.35;
uniform float bump_scale2 = 0.2;
uniform float wave_tile = 0.6;
uniform float wave_speed = 0.6;
// Cuánto deforman las ondas lo que se ve a través (en pantalla).
uniform float refract_distortion = 0.025;

uniform vec3 reflection_color : source_color = vec3(0.75, 0.92, 1.0);
uniform float fresnel_coeff = 3.0;
uniform float fresnel_strength = 0.45;
uniform float smoothness = 0.9;

uniform vec3 foam_color : source_color = vec3(0.95, 0.99, 1.0);
// Metros de agua con espuma en la orilla.
uniform float shore_foam = 0.18;

varying vec3 world_position;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Distancia al borde de celda más cercano (F2 - F1): chica sobre las líneas de las cáusticas.
float cell_edges(vec2 p, float t) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = 0.5 + 0.5 * sin(t + 6.2831 * hash2(n + g));
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return sqrt(d2) - sqrt(d1);
}

float caustics(vec2 p, float t) {
	p += 0.35 * vec2(sin(p.y * 1.9 + t * 0.7), sin(p.x * 1.6 - t * 0.6));
	float a = cell_edges(p * caustics_scale.x + vec2(t * caustics_speed.x, 0.0), t * 0.6);
	float b = cell_edges(p * caustics_scale.y + vec2(0.0, t * caustics_speed.y), t * 0.8 + 3.0);
	return smoothstep(0.12, 0.0, a) * 0.6 + smoothstep(0.1, 0.0, b) * 0.5;
}

float wave_height(vec2 p, float t) {
	float h = sin(p.x * 1.3 + t) * 0.5 + sin(p.y * 1.7 - t * 1.2) * 0.5;
	h += sin((p.x + p.y) * 2.1 + t * 1.6) * 0.35 * bump_scale2 / max(bump_scale, 0.001);
	return h;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 p = world_position.xz * wave_tile;
	float e = 0.05;
	float h = wave_height(p, t);
	vec2 slope = vec2(wave_height(p + vec2(e, 0.0), t) - h, wave_height(p + vec2(0.0, e), t) - h) / e;
	vec3 world_normal = normalize(vec3(-slope.x * bump_scale, 1.0, -slope.y * bump_scale));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	float thickness = max(VERTEX.z - view.z, 0.0);
	vec2 refracted_uv = SCREEN_UV + world_normal.xz * refract_distortion * clamp(thickness, 0.0, 1.0);
	float refracted_depth = texture(depth_texture, refracted_uv).r;
	vec4 refracted_view = INV_PROJECTION_MATRIX * vec4(refracted_uv * 2.0 - 1.0, refracted_depth, 1.0);
	refracted_view.xyz /= refracted_view.w;
	if (refracted_view.z > VERTEX.z) {
		refracted_uv = SCREEN_UV;
		refracted_view = view;
	}
	vec3 bottom = (INV_VIEW_MATRIX * vec4(refracted_view.xyz, 1.0)).xyz;
	float water_depth = max(VERTEX.z - refracted_view.z, 0.0);

	float near = clamp(water_depth / depth_color_range, 0.0, 1.0);
	float far = clamp(water_depth / depth_global_range, 0.0, 1.0);
	vec3 tint = mix(mix(shallow_water_color, water_color, near), muddy_color, far);
	vec3 background = textureLod(screen_texture, refracted_uv, 0.0).rgb;
	background += caustics_color * caustics(bottom.xz, TIME) * caustics_strength * (1.0 - clamp(water_depth / caustics_depth, 0.0, 1.0));
	float seen = clarity * (1.0 - near * 0.6) * (1.0 - far);
	vec3 color = mix(tint, background * mix(vec3(1.0), shallow_water_color, 0.5), seen);
	color += caustics_color * caustics(bottom.xz, TIME) * caustics_strength * 0.35 * far;

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_coeff);
	color = mix(color, reflection_color, fresnel * fresnel_strength);
	float foam = step(thickness, shore_foam * (0.7 + 0.6 * h * 0.5 + 0.3));
	color = mix(color, foam_color, foam);

	ALBEDO = color * 0.15;
	EMISSION = color * 0.85;
	ROUGHNESS = 1.0 - smoothness;
	SPECULAR = 0.6;
	METALLIC = 0.0;
	ALPHA = 1.0;
}
