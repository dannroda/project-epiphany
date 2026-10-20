class_name SwordBeam
extends Hitbox
## Rayo de espada (11.34 paso 5): sale con la vida llena, vuela `reach` metros hacia su -Z (con la salida delante del player, la punta llega a 6 m de él) y solo le pega a enemigos:
## no prende ojos, cristales ni placas, ni rompe nada. Se deshace contra una pared o en el primer enemigo.

@export var speed := 14.0
@export var reach := 5.0
## Quien lo tira: su escudo, delante del pecho, no lo deshace.
var shooter: Node

var _travelled := 0.0


func _ready() -> void:
	super()
	landed.connect(func(_hurtbox: Hurtbox) -> void: _vanish())


func _physics_process(delta: float) -> void:
	super(delta)
	var step := speed * delta
	global_position += -global_basis.z * step
	_travelled += step
	if _travelled >= reach:
		_vanish()


func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox and hurtbox.team == EntityConfig.Team.ENEMY:
		super(area)


func _on_body_entered(body: Node3D) -> void:
	if shooter and shooter.is_ancestor_of(body):
		return
	if not (body is RigidBody3D or body is CharacterBody3D):
		_vanish()


func _vanish() -> void:
	if is_queued_for_deletion():
		return
	Feel.burst(&"sparks", global_position, global_basis.z)
	queue_free()
