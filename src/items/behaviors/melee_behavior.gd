class_name MeleeBehavior
extends ItemBehavior
## El primer golpe, los que le siguen en combo y el giro cargado.

@export var attack: AttackData
## Los golpes que siguen a `attack` si se vuelve a apretar dentro de la ventana del combo (Attacking.combo_window).
@export var combo: Array[AttackData] = []
## Mantener ataque y soltar con la carga llena (SwordCharge); sin él, no carga.
@export var spin: AttackData


func get_animation(_item: ItemData) -> StringName:
	return attack.animation if attack else &""


func chain() -> Array[AttackData]:
	var all: Array[AttackData] = [attack]
	all.append_array(combo)
	return all
