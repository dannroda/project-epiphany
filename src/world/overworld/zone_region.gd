class_name ZoneRegion
extends Resource
## Región del overworld: sus zonas son un solo lugar para el HUD, el mapa y la persecución.

@export var id: StringName = &""
@export var display_name: String = ""
## Las regiones del mismo grupo no sueltan al player al pasar de una a otra; vacío, solo la región.
@export var chase_group: StringName = &""
## La zona (por su id) sobre la que va el nombre en el mapa.
@export var label_zone: StringName = &""


func chase_key() -> StringName:
	return chase_group if not chase_group.is_empty() else id
