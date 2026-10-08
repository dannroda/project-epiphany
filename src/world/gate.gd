class_name Gate
extends StaticBody3D
## Reja que se hunde en el piso al abrirse (la abre un interruptor, un cristal, un enemigo vencido…).

signal opened

@export var drop := 2.3
@export var duration := 0.6

var is_open := false


func open() -> void:
	if is_open:
		return
	is_open = true
	$CollisionShape3D.set_deferred(&"disabled", true)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y - drop, duration)
	Feel.sfx(&"secret", global_position)
	Feel.burst(&"dust", global_position + Vector3.UP * 0.2, Vector3.UP)
	opened.emit()
