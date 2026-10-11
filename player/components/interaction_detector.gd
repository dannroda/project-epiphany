class_name InteractionDetector
extends Area3D
## Elige el Interactable más cercano y de frente; `interact` lo activa si el player está libre.

## El HUD muestra el prompt del foco; null = nada que hacer ahora.
signal focus_changed(target: Interactable)

@export var player: PlayerCharacter
## Cuánto pesa estar de frente contra estar cerca (0 = solo distancia).
@export_range(0.0, 1.0) var facing_weight := 0.6
## Cuánto suma cada punto de prioridad.
@export var priority_weight := 0.3

var focus: Interactable


func _init() -> void:
	collision_layer = 0
	collision_mask = Interactable.LAYER
	monitorable = false


func _unhandled_input(event: InputEvent) -> void:
	if not player.controls.event_pressed(event, &"interact") or not player.can_interact():
		return
	var target := best()
	if target:
		target.interact(player)
		get_viewport().set_input_as_handled()
		_set_focus(null)


## Sin foco en combate (lock-on) o si el player no está libre (Hurt, Dodging, ItemGet…).
func _physics_process(_delta: float) -> void:
	var free := player.can_interact() and player.targeting.current == null
	_set_focus(best() if free else null)


func _set_focus(target: Interactable) -> void:
	if target != focus:
		focus = target
		focus_changed.emit(target)


func best() -> Interactable:
	var forward := player.model.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var chosen: Interactable = null
	var best_score := -INF
	for area in get_overlapping_areas():
		var interactable := area as Interactable
		if interactable == null or not interactable.enabled:
			continue
		var to := interactable.global_position - player.global_position
		to.y = 0.0
		var score := -to.length() + facing_weight * to.normalized().dot(forward) * 2.0 + interactable.prompt_priority * priority_weight
		if score > best_score:
			best_score = score
			chosen = interactable
	return chosen
