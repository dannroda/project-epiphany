class_name Hurtbox
extends Area3D
## La entidad decide qué hacer con el golpe (bloqueo, daño, reflejo).

signal hit(info: DamageInfo)

## Cómo suena y se siente un espadazo que la toca (Feel.sfx &"hit_<surface>"); "none": el dueño da su propia respuesta (pasto, vasijas).
@export_enum("flesh", "metal", "stone", "none") var surface := "flesh"

var team: EntityConfig.Team = EntityConfig.Team.NEUTRAL


func receive(info: DamageInfo) -> void:
	hit.emit(info)
