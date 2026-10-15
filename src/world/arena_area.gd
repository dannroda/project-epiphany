class_name ArenaArea
extends Node3D
## La sala de una pelea fuera de las mazmorras (overworld): un rectángulo en XZ (su CollisionShape3D, una caja) que
## avisa como un Room cuando entra el primer player y cuando ya no queda ninguno. Lo usa ArenaFight en vez de `room`.

signal player_entered(area: ArenaArea)
signal player_left(area: ArenaArea)

var has_player := false


func _physics_process(_delta: float) -> void:
	var inside := Players.all.any(func(player: PlayerCharacter) -> bool: return bounds().has_point(Vector2(player.global_position.x, player.global_position.z)))
	if inside == has_player:
		return
	has_player = inside
	if inside:
		player_entered.emit(self)
	else:
		player_left.emit(self)


func bounds() -> Rect2:
	var shape := get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if shape == null or not shape.shape is BoxShape3D:
		return Rect2(Vector2(global_position.x, global_position.z), Vector2.ZERO)
	var size := (shape.shape as BoxShape3D).size
	var center := shape.global_position
	return Rect2(center.x - size.x / 2.0, center.z - size.z / 2.0, size.x, size.z)
