class_name TremorZone
extends Area3D
## Temblores lejanos: mientras el player está adentro, cada tanto una sacudida suave y un retumbo grave.

signal trembled

@export var interval := 6.0
@export var amount := 0.18

var _inside := false
var _next := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerCharacter:
			_inside = true
			_next = 1.5)
	body_exited.connect(func(body: Node3D) -> void:
		if body is PlayerCharacter:
			_inside = false)


func _physics_process(delta: float) -> void:
	if not _inside:
		return
	_next -= delta
	if _next <= 0.0:
		_next = interval
		tremor()


func tremor() -> void:
	trembled.emit()
	Feel.shake(amount)
	var player := Players.lead()
	if player:
		Feel.sfx(&"rumble", player.global_position)
