class_name Stairs
extends Area3D
## Escalera a otro piso de la misma escena: fundido corto y los players aparecen en `to` (afuera de la escalera de
## llegada, así no vuelve a dispararse).

@export var to: Node3D
## Reja que la cierra: mientras no esté abierta, la escalera no lleva a ningún lado.
@export var gate: Gate
@export var fade_time := 0.2

var _busy := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerCharacter and to and not _busy and not SceneFlow.traveling and (gate == null or gate.is_open):
			_climb(body))


func _climb(crosser: PlayerCharacter) -> void:
	_busy = true
	Feel.sfx(&"stairs", crosser.global_position)
	await SceneFlow.fade_out(fade_time)
	var side := to.global_basis.x.normalized()
	var i := 0
	for player in Players.all:
		var spot := Vector3.ZERO if player == crosser else side * 0.7 * (1 if i % 2 == 0 else -1) * (1 + i / 2)
		if player != crosser:
			i += 1
		player.global_position = to.global_position + spot
		player.velocity = Vector3.ZERO
	get_tree().call_group(TopDownCamera.GROUP, &"reset_room")
	await get_tree().physics_frame
	get_tree().call_group(TopDownCamera.GROUP, &"snap_to_target")
	await SceneFlow.fade_in(fade_time)
	_busy = false
