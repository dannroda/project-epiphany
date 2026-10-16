class_name Hurtbox
extends Area3D
## La entidad decide qué hacer con el golpe (bloqueo, daño, reflejo).

signal hit(info: DamageInfo)

## Cómo suena y se siente un espadazo que la toca (Feel.sfx &"hit_<surface>"); "none": el dueño da su propia respuesta (pasto, vasijas).
@export_enum("flesh", "metal", "stone", "none") var surface := "flesh"

## El cuerpo que pisa, para lo que pega solo por el piso (ondas, pinchos). Sin él cuenta como en el piso: un enemigo
## quieto no llama a move_and_slide y is_on_floor() le daría false.
@export var body: CharacterBody3D

var team: EntityConfig.Team = EntityConfig.Team.NEUTRAL


func receive(info: DamageInfo) -> void:
	hit.emit(info)


func is_grounded() -> bool:
	return body == null or body.is_on_floor()
