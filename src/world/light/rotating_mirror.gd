class_name RotatingMirror
extends StaticBody3D
## Espejo del haz que gira `step` de un espadazo (D4, la Cumbre). Las flechas, las bombas y el gancho no lo mueven.

signal turned

@export var step := PI / 2.0
@export var turn_time := 0.25

@onready var hurtbox: Hurtbox = $Hurtbox

var _turning := false


func _ready() -> void:
	hurtbox.hit.connect(_on_hit)


func _on_hit(info: DamageInfo) -> void:
	if _turning or info.element != &"" or info.source is Projectile:
		return
	_turning = true
	Feel.sfx(&"click", global_position)
	Feel.burst(&"sparks", global_position + Vector3.UP, Vector3.UP)
	var tween := create_tween()
	tween.tween_property(self, ^"rotation:y", rotation.y + step, turn_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	_turning = false
	turned.emit()
