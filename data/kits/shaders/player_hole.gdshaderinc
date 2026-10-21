// Agujero alrededor del player en las paredes que lo tapan (xyz: sus pies, w: cuánto está abierto, 0–1); lo pone TopDownCamera.
global uniform vec4 player_hole;
uniform float hole_radius = 1.4;
// Por debajo de los pies + esto no se recorta: el piso y el zócalo quedan.
uniform float hole_floor = 0.3;
// Una cámara más alta que esto sobre el player es la de la foto del mapa (OverworldMap, a 60 m), que no recorta; la del
// juego llega a unos 38 m (offset de 34 m girado cenital).
const float HOLE_MAX_CAMERA_HEIGHT = 45.0;

// Más cerca de la cámara que el player y dentro del círculo a su alrededor (borde con dither).
bool in_player_hole(vec3 world_pos, vec3 view_pos, mat4 view_matrix, vec3 camera_pos, vec2 frag_coord) {
	if (player_hole.w <= 0.0 || world_pos.y < player_hole.y + hole_floor || camera_pos.y > player_hole.y + HOLE_MAX_CAMERA_HEIGHT) {
		return false;
	}
	vec3 center = (view_matrix * vec4(player_hole.xyz + vec3(0.0, 1.0, 0.0), 1.0)).xyz;
	if (view_pos.z < center.z + 0.2) {
		return false;
	}
	float distance_on_player = length(view_pos.xy * (center.z / view_pos.z) - center.xy) / hole_radius;
	float dither = fract(sin(dot(floor(frag_coord * 0.5), vec2(12.9898, 78.233))) * 43758.5453);
	return distance_on_player < (0.85 + 0.15 * dither) * player_hole.w;
}
