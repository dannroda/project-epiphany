class_name TremorZone
extends Area3D
## Temblores lejanos: mientras algún player está adentro, cada tanto una sacudida suave y un retumbo grave.

signal trembled

@export var interval := 6.0
@export var amount := 0.18

var _players := 0
var _next := 0.0


func _ready() -> void:
	PhysicsLayers.sensor(self)
	body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerCharacter:
			if _players == 0:
				_next = 1.5
			_players += 1)
	body_exited.connect(func(body: Node3D) -> void:
		if body is PlayerCharacter:
			_players = maxi(_players - 1, 0))


func _physics_process(delta: float) -> void:
	if _players == 0:
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
