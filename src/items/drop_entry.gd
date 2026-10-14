class_name DropEntry
extends Resource
## Una fila de la DropTable. Sin ítem ni curación = "nada".

@export var item: ItemData
@export_range(1, 99, 1, "or_greater") var amount: int = 1
@export_range(0, 40, 1, "or_greater") var heal: int = 0 ## HP que cura al agarrarlo (corazón = 4)
@export_range(0.0, 10.0, 0.05, "or_greater") var weight: float = 1.0
## Solo sale si el player ya tiene este ítem (la bolsa para las bombas, el arco para las flechas).
@export var requires: ItemData


func is_nothing() -> bool:
	return item == null and heal == 0
