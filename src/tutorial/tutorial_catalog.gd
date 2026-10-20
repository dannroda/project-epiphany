class_name TutorialCatalog
extends Resource
## Los mini tutoriales de ítems (11.105), en el orden en que se consiguen.

@export var tutorials: Array[TutorialData] = []


func for_item(id: StringName) -> TutorialData:
	for tutorial in tutorials:
		if tutorial.item.id == id:
			return tutorial
	return null


## La tarea pendiente: la primera tarjeta ya vista y todavía no hecha.
func pending() -> TutorialData:
	for tutorial in tutorials:
		if tutorial.is_shown() and not tutorial.is_done():
			return tutorial
	return null
