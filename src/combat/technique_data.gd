class_name TechniqueData
extends Resource
## Una técnica de espada (11.34) para la fila Técnicas de Equipo y el cartel de técnica nueva.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Cómo se hace, en una línea.
@export var how: String
@export var damage: String
@export var icon: Texture2D
## El flag que la enseña (una piedra de técnica); vacío = se tiene desde el inicio.
@export var flag: StringName
## Dónde se aprende (clave de traducción), para el detalle.
@export var learned_at: String


func is_learned() -> bool:
	return flag == &"" or GameState.get_flag(flag) == true
