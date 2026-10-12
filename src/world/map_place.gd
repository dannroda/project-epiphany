class_name MapPlace
extends Marker3D
## Un lugar con nombre propio en el mapa del overworld (mazmorra, cueva, santuario): ícono y nombre, una vez visitada
## su zona.

enum Kind { DUNGEON, CAVE, SHRINE }

@export var display_name: String = ""
@export var kind := Kind.CAVE
