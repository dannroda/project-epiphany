class_name Interactable
extends Area3D

signal interacted(by: PlayerCharacter)

const LAYER := 1 << 5

@export var prompt: String = "Abrir" ## Lo muestra el HUD en el botón contextual (4.1)
@export var enabled: bool = true


func _init() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false


func interact(by: PlayerCharacter) -> void:
	if enabled:
		interacted.emit(by)
