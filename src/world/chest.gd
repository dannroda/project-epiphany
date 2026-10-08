class_name Chest
extends StaticBody3D

@export var item: ItemData
@export var amount: int = 1
@export var flag: StringName ## p. ej. &"d1_chest_bow"
@export var big: bool = false ## Cofre grande: ítem de la mazmorra / llave del jefe

@onready var interactable: Interactable = $Interactable
@onready var lid: Node3D = %Lid

const OPEN_ANGLE := -110.0


func _ready() -> void:
	if big:
		scale = Vector3.ONE * 1.4
	if GameState.get_flag(flag):
		lid.rotation_degrees.x = OPEN_ANGLE
		interactable.enabled = false
	interactable.interacted.connect(_open)


func _open(by: PlayerCharacter) -> void:
	interactable.enabled = false
	GameState.set_flag(flag, true)
	GameState.give(item, amount)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(lid, "rotation_degrees:x", OPEN_ANGLE, 0.35)
	Feel.sfx(&"click", global_position)
	by.play_item_get(item, amount)
