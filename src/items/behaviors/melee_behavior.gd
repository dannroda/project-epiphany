class_name MeleeBehavior
extends ItemBehavior
## Un golpe por botón: un combo de verdad sería una lista que avanza, y hoy no la hay.

@export var attack: AttackData


func get_animation(_item: ItemData) -> StringName:
	return attack.animation if attack else &""
