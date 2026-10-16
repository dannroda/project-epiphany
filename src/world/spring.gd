class_name Spring
extends Node3D
## Vertiente de agua bendita: con una botella vacía, "Llenar" le pone agua bendita (se puede volver cuantas veces
## se quiera); sin botella vacía, "Beber" devuelve toda la vida. La botella vacía en un botón también la llena acá.

const GROUP := &"springs"

const DIALOGUE: DialogueResource = preload("res://data/dialogue/overworld.dialogue")
@export var fills: ItemData

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group(GROUP)
	interactable.interacted.connect(_use)
	GameState.inventory.changed.connect(func(_id: StringName, _count: int) -> void: _update_prompt())
	GameState.bottle_changed.connect(func(_bottle: StringName, _content: StringName) -> void: _update_prompt())
	GameState.loaded.connect(_update_prompt)
	_update_prompt()


## La vertiente al alcance de `user` (dentro de su zona de "Llenar"), o null.
static func reaching(user: Node3D) -> Spring:
	for spring: Spring in user.get_tree().get_nodes_in_group(GROUP):
		if spring.reaches(user.global_position):
			return spring
	return null


func reaches(point: Vector3) -> bool:
	var shape := interactable.get_node(^"CollisionShape3D") as CollisionShape3D
	var box := shape.shape as BoxShape3D
	var local := shape.global_transform.affine_inverse() * point
	return absf(local.x) <= box.size.x / 2.0 and absf(local.z) <= box.size.z / 2.0 and absf(local.y) <= box.size.y


func fill_bottle(bottle: StringName, by: PlayerCharacter) -> void:
	Feel.burst(&"sparkle", global_position + Vector3.UP * 0.5, Vector3.UP)
	GameState.fill(bottle, fills.id)
	by.play_item_get(fills)


func can_fill() -> bool:
	return GameState.bottle_with(GameState.EMPTY_BOTTLE) != &""


func _update_prompt() -> void:
	interactable.prompt = "PROMPT_FILL" if can_fill() else "PROMPT_DRINK"


func _use(by: PlayerCharacter) -> void:
	if can_fill():
		fill_bottle(GameState.bottle_with(GameState.EMPTY_BOTTLE), by)
		return
	Feel.burst(&"sparkle", global_position + Vector3.UP * 0.5, Vector3.UP)
	by.health.heal(by.health.max_health)
	Feel.sfx(&"heal", by.global_position)
	TextBox.open(DIALOGUE, "spring_drink")
