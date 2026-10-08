class_name Hurtbox
extends Area3D
## La entidad decide qué hacer con el golpe (bloqueo, daño, reflejo).

signal hit(info: DamageInfo)

var team: EntityConfig.Team = EntityConfig.Team.NEUTRAL


func receive(info: DamageInfo) -> void:
	hit.emit(info)
