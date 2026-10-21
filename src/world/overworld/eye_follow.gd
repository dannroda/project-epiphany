class_name EyeFollow
extends Node3D
## Un iris que mira al jugador más cercano: se corre dentro de la almendra (en su plano XY) hacia donde está.

## Cuánto se puede correr el iris, a lo ancho y a lo alto.
@export var reach := Vector2(0.16, 0.035)
## A qué distancia del ojo el iris ya llega al borde.
@export var range_full := 6.0
@export var speed := 6.0

var _rest: Vector3


func _ready() -> void:
	_rest = position


func _process(delta: float) -> void:
	var goal := Vector2.ZERO
	var player := Players.nearest(global_position)
	if player:
		var local := (get_parent() as Node3D).to_local(player.global_position) - _rest
		var aim := Vector2(local.x, local.y) / range_full
		goal = aim.limit_length(1.0) * reach
	var offset := Vector2(position.x - _rest.x, position.y - _rest.y).lerp(goal, 1.0 - exp(-speed * delta))
	position = _rest + Vector3(offset.x, offset.y, 0.0)
