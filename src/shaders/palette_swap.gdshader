shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_nearest;

// 0: Todo Azul | 1: Todo Verde | 2: Todo Amarillo | 3: Todo Rojo
uniform int suit_color : hint_range(0, 3) = 3; 

void fragment() {
	vec2 uv = UV;
	
	// Si está en el cuadrante superior derecho (la zona de colores del traje)
	if (uv.y < 0.5 && uv.x >= 0.5) {
		// Preserva el gradiente/sombreado dentro de la columna (cada columna mide 0.125)
		float local_x = mod(uv.x - 0.5, 0.125);
		
		// Fuerza a que TANTO el lado izquierdo como el derecho lean de la misma columna elegida
		uv.x = 0.5 + (float(suit_color) * 0.125) + local_x;
	}
	
	vec4 tex_color = texture(albedo_texture, uv);
	ALBEDO = tex_color.rgb;
}
