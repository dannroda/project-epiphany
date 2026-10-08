class_name DropEntry
extends Resource
## Una fila de la DropTable. Sin ítem ni curación = "nada".

@export var item: ItemData
@export var amount: int = 1
@export var heal: int = 0 ## HP que cura al agarrarlo (corazón = 4)
@export var weight: float = 1.0
## Solo sale si el player ya tiene este ítem (la bolsa para las bombas, el arco para las flechas).
@export var requires: ItemData


func is_nothing() -> bool:
	return item == null and heal == 0
