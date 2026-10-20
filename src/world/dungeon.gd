@tool
class_name Dungeon
extends Node
## Va en la escena de cada mazmorra: mientras está en el árbol, GameState.current_dungeon es su id. El id es también el
## prefijo de los flags de la mazmorra (ch_, qv_…), sus llaves, su mapa y su brújula.

const GROUP := &"dungeons"

@export var id: StringName:
	set(value):
		id = value
		update_configuration_warnings()
@export var display_name: String = ""
@export var floor_name: String = "PLACE_FLOOR_1"


func _enter_tree() -> void:
	add_to_group(GROUP)
	if not Engine.is_editor_hint():
		GameState.current_dungeon = id


## La de la escena actual: al cambiar de escena la anterior puede seguir en el grupo un cuadro.
static func current(tree: SceneTree) -> Dungeon:
	for dungeon: Dungeon in tree.get_nodes_in_group(GROUP):
		if tree.current_scene and tree.current_scene.is_ancestor_of(dungeon):
			return dungeon
	return null


## Viajando lo pone SceneFlow cuando entra la escena nueva.
func _exit_tree() -> void:
	if not Engine.is_editor_hint() and not SceneFlow.traveling and GameState.current_dungeon == id:
		GameState.current_dungeon = &""


func _get_configuration_warnings() -> PackedStringArray:
	if id == &"":
		return PackedStringArray(["Falta el id: sin él comparte llaves, mapa y brújula con otra mazmorra."])
	if "_" in String(id):
		return PackedStringArray(["El id no lleva _: es el prefijo de los flags (ch, qv…)."])
	return PackedStringArray()
