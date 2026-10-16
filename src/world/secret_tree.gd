class_name SecretTree
extends Breakable
## Queñoa que ningún golpe voltea: el choque de las sandalias la sacude y suelta su pieza de corazón.

@export var piece: HeartPiece


func _on_hit(info: DamageInfo) -> void:
	if info.element != DamageInfo.DASH:
		Feel.sfx(&"hit", global_position)
		return
	shake()
	if piece:
		piece.reveal()
