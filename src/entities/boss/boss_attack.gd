class_name BossAttack
extends Resource
## Un ataque del jefe y cómo lo puntúa la utilidad (`Boss.choose_attack`).

enum User { HAND, EYE }

@export var id: StringName
@export var user := User.HAND
## Fases en las que se puede elegir.
@export var phases: Array[int] = [1]
## La pose de la mano mientras lo hace.
@export var pose: BossHand.Pose = BossHand.Pose.OPEN
@export var attack: AttackData
## Distancia del player al que ataca (m) donde más conviene: rinde 1 dentro del rango y cae a 0 a `falloff` metros.
@export var ideal_distance := Vector2(0.0, 4.0)
@export var falloff := 6.0
@export var weight := 1.0
