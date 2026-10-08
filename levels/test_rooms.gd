extends Node3D
## Dos salas pegadas para probar la cámara por sala, el cruce y la reaparición en mazmorra.


func _ready() -> void:
	if GameState.current_dungeon == &"":
		GameState.current_dungeon = &"test_rooms"
