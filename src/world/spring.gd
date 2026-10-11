class_name Spring
extends Node3D
## Vertiente de agua bendita: con una botella vacía, "Llenar" la cambia por agua bendita (se puede volver cuantas veces
## se quiera); sin botella vacía, "Beber" devuelve toda la vida.

const DIALOGUE: DialogueResource = preload("res://data/dialogue/overworld.dialogue")
const EMPTY := &"bottle_empty"

@export var fills: ItemData

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.interacted.connect(_use)
	GameState.inventory.changed.connect(func(_id: StringName, _count: int) -> void: _update_prompt())
	_update_prompt()


func can_fill() -> bool:
	return GameState.inventory.has(EMPTY)


func _update_prompt() -> void:
	interactable.prompt = "PROMPT_FILL" if can_fill() else "PROMPT_DRINK"


func _use(by: PlayerCharacter) -> void:
	Feel.burst(&"sparkle", global_position + Vector3.UP * 0.5, Vector3.UP)
	if can_fill():
		GameState.swap_item(EMPTY, fills)
		by.play_item_get(fills)
		return
	var health: Health = by.get_node(^"Health")
	health.heal(health.max_health)
	Feel.sfx(&"heal", by.global_position)
	TextBox.open(DIALOGUE, "spring_drink")
