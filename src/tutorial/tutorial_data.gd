class_name TutorialData
extends Resource
## Mini tutorial (11.105): el de un ítem trae la tarjeta después del item get, la tarea del chip del HUD hasta hacerla
## una vez y a qué objetivos apunta la pista por demora; los de los controles básicos son solo el aviso del chip.

## Cuándo aparece: al cerrar el item get de `item`, desde el arranque o con un enemigo cerca.
enum Trigger { ITEM_GET, START, ENEMY_NEAR }

@export var id: StringName
@export var trigger := Trigger.ITEM_GET
@export var item: ItemData
## Claves de traducción de los tres renglones de la tarjeta; BOTÓN admite {btn:acción} e {item:id}.
@export var what: String
@export var button: String
@export var try: String
## La tarea del chip del HUD, y su botón: vacío = el botón al que está asignado el ítem.
@export var task: String
@export var action: StringName
## Apretar una de estas acciones la completa (los controles básicos).
@export var done_actions: Array[StringName] = []
## Lo que la completa: los nodos de este grupo que emiten `done_signal`. Sin grupo ni acciones, usar el ítem una vez.
@export var target_group: StringName
@export var done_signal: StringName = &"activated"
## Propiedad de un objetivo que dice que ya está resuelto (la pista no lo marca); vacía = siempre se puede marcar.
@export var solved_property: StringName


func shown_flag() -> StringName:
	return StringName("tut_%s_shown" % id)


func done_flag() -> StringName:
	return StringName("tut_%s_done" % id)


func is_shown() -> bool:
	return trigger == Trigger.START or GameState.get_flag(shown_flag()) == true


func is_done() -> bool:
	return GameState.get_flag(done_flag()) == true


func is_solved(target: Node) -> bool:
	return solved_property != &"" and target.get(solved_property) == true


## La acción del botón del chip, o vacía si el ítem no está en ningún botón.
func chip_action() -> StringName:
	if action != &"" or not item:
		return action
	var button := GameState.item_buttons.find(item.id)
	return PlayerCharacter.ITEM_ACTIONS[button] if button >= 0 else &""
