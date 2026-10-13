class_name RopeLadder
extends Node3D
## Escalera de soga enrollada al borde de un risco: se descuelga desde arriba y queda colgada (flag); después se sube
## y se baja como una escalera. El origen va en el borde de arriba y +Z apunta hacia afuera del risco.

@export var flag: StringName
@export var unroll_time := 0.6

@onready var interactable: Interactable = $Interactable
@onready var coil: Node3D = $Coil
@onready var ladder: Node3D = $Ladder
@onready var top: Stairs = $Top
@onready var bottom: Stairs = $Bottom


func _ready() -> void:
	interactable.interacted.connect(func(_by: PlayerCharacter) -> void: unroll())
	GameState.loaded.connect(_sync)
	_sync()


func is_down() -> bool:
	return GameState.get_flag(flag) == true


func unroll() -> void:
	if is_down():
		return
	GameState.set_flag(flag, true)
	Feel.sfx(&"secret", global_position)
	_sync()
	ladder.scale.y = 0.05
	create_tween().tween_property(ladder, ^"scale:y", 1.0, unroll_time).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _sync() -> void:
	var down := is_down()
	coil.visible = not down
	ladder.visible = down
	interactable.enabled = not down
	interactable.set_deferred(&"monitorable", not down)
	for stairs: Stairs in [top, bottom]:
		stairs.set_deferred(&"monitoring", down)
