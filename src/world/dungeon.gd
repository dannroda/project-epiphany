class_name Dungeon
extends Node
## Va en la escena de cada mazmorra: mientras está en el árbol, GameState.current_dungeon es su id.

@export var id: StringName = &"d1"


func _enter_tree() -> void:
	GameState.current_dungeon = id


func _exit_tree() -> void:
	if GameState.current_dungeon == id:
		GameState.current_dungeon = &""
