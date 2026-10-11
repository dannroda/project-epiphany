class_name Pit
extends Area3D
## Debajo de un hueco: el player que cae pierde vida y vuelve a la entrada de la sala.

@export var damage := 2
## Adónde vuelve el que cae; si no hay, a la entrada de la sala o al punto de aparición.
@export var respawn: Node3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerCharacter:
			_fall.call_deferred(body))


func _fall(player: PlayerCharacter) -> void:
	player.health.damage(damage)
	if player.is_dead:
		return
	var back: Variant = respawn.global_position if respawn else GameState.room_entry
	if back == null:
		var point := SpawnPoint.find(get_tree(), GameState.spawn_point)
		back = point.global_position if point else player.global_position + Vector3.UP * 3.0
	player.global_position = back
	player.velocity = Vector3.ZERO
	Feel.sfx(&"hurt", player.global_position)
	get_tree().call_group(&"room_camera", &"snap_to_target")
