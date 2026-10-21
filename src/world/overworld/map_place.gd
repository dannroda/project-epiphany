class_name MapPlace
extends Marker3D
## Un lugar con nombre propio en el mapa del overworld (mazmorra, cueva, santuario): ícono y nombre, una vez visitada
## su zona.

enum Kind { DUNGEON, CAVE, SHRINE }

@export var display_name: String = ""
@export var kind := Kind.CAVE
## Si no está vacío, el lugar sale recién con este flag (una entrada escondida, como un muro agrietado).
@export var reveal_flag: StringName = &""


func is_revealed() -> bool:
	return reveal_flag == &"" or GameState.get_flag(reveal_flag)
