class_name SecretTree
extends Breakable
## Queñoa que ningún golpe voltea: el choque de las sandalias la sacude y suelta su pieza de corazón, o lo de `drops`
## (una vez por visita).

@export var piece: HeartPiece

var _dropped := false


func _on_hit(info: DamageInfo) -> void:
	if info.element != DamageInfo.DASH:
		Feel.sfx(&"hit", global_position)
		return
	shake()
	if piece:
		piece.reveal()
	elif drops and not _dropped:
		_dropped = true
		drops.drop_at.call_deferred(global_position + Vector3.UP * drop_height, get_parent())
