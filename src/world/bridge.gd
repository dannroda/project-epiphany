class_name Bridge
extends StaticBody3D
## Puente que sube desde el fondo de un hueco cuando se cumplen sus interruptores (y queda arriba).

@export var switches: Array[NodePath] = []
@export var condition: Wiring.Condition = Wiring.Condition.ALL
@export var drop := 3.0
@export var duration := 0.8

var is_up := false
var _base_y := 0.0
var _wiring: Wiring


func _ready() -> void:
	_base_y = position.y
	position.y -= drop
	$CollisionShape3D.disabled = true
	if switches.is_empty():
		return
	_wiring = Wiring.create(self, switches, condition)
	_wiring.changed.connect(func(satisfied: bool) -> void:
		if satisfied:
			raise())
	if _wiring.is_satisfied():
		raise(false)


func raise(animate := true) -> void:
	if is_up:
		return
	is_up = true
	$CollisionShape3D.set_deferred(&"disabled", false)
	if not animate:
		position.y = _base_y
		return
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", _base_y, duration)
	Feel.sfx(&"secret", global_position)
