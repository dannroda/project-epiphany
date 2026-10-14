@tool
class_name Dungeon
extends Node
## Va en la escena de cada mazmorra: mientras está en el árbol, GameState.current_dungeon es su id. El id es también el
## prefijo de los flags de la mazmorra (ch_, qv_…), sus llaves, su mapa y su brújula.

@export var id: StringName:
	set(value):
		id = value
		update_configuration_warnings()
@export var display_name: String = ""
@export var floor_name: String = "PLACE_FLOOR_1"


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		GameState.current_dungeon = id


func _exit_tree() -> void:
	if not Engine.is_editor_hint() and GameState.current_dungeon == id:
		GameState.current_dungeon = &""


func _get_configuration_warnings() -> PackedStringArray:
	if id == &"":
		return PackedStringArray(["Falta el id: sin él comparte llaves, mapa y brújula con otra mazmorra."])
	if "_" in String(id):
		return PackedStringArray(["El id no lleva _: es el prefijo de los flags (ch, qv…)."])
	return PackedStringArray()
