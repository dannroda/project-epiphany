class_name Pit
extends Area3D
## Debajo de un hueco: el player que cae pierde vida y vuelve a la entrada de la sala.

@export var damage := 2
## Adónde vuelve el que cae: el más cercano entre él y sus hijos a donde pisó suelo por última vez; si no hay, a la entrada de la
## sala o al punto de aparición.
@export var respawn: Node3D
## Si es agua: el que cae salpica en su superficie.
@export var water: Node3D
## Segundos que el player no camina al volver.
@export var still_time := 0.5


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerCharacter:
			_fall.call_deferred(body))


func _fall(player: PlayerCharacter) -> void:
	if water:
		var at := Vector3(player.global_position.x, water.global_position.y, player.global_position.z)
		Feel.burst(&"splash", at, Vector3.UP)
		Feel.sfx(&"splash", at)
	var info := DamageInfo.make(damage, 0.0, self)
	info.unavoidable = true
	player.hurtbox.receive(info)
	if player.is_dead:
		return
	var back: Variant = _nearest_respawn(player.last_ground) if respawn else GameState.room_entry
	if back == null:
		var point := SpawnPoint.find(get_tree(), GameState.spawn_point)
		back = point.global_position if point else player.global_position + Vector3.UP * 3.0
	player.global_position = back
	player.velocity = Vector3.ZERO
	player.controls.hold_still(still_time)
	get_tree().call_group(TopDownCamera.GROUP, &"snap_to_target")


func _nearest_respawn(from: Vector3) -> Vector3:
	var best := respawn.global_position
	for child in respawn.get_children():
		if child is Node3D and from.distance_squared_to(child.global_position) < from.distance_squared_to(best):
			best = child.global_position
	return best

