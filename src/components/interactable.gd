class_name Interactable
extends Area3D

signal interacted(by: PlayerCharacter)
## Algún player lo tiene de foco (el prompt del HUD apunta a esto).
signal focused(on: bool)

const LAYER := 1 << 5

@export var prompt: String = "PROMPT_OPEN" ## Lo muestra el HUD en el botón contextual (4.1)
@export var enabled: bool = true
## Desempata entre interactuables parecidos (cofre > tablilla).
@export var prompt_priority: int = 0

var _focus_count := 0


func _init() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false


func interact(by: PlayerCharacter) -> void:
	if enabled:
		interacted.emit(by)


func set_focus(on: bool) -> void:
	var was := _focus_count > 0
	_focus_count = maxi(0, _focus_count + (1 if on else -1))
	if (_focus_count > 0) != was:
		focused.emit(_focus_count > 0)
