class_name InteractionDetector
extends Area3D
## Elige el Interactable más cercano y de frente; `interact` lo activa si el player está libre.

@export var player: PlayerCharacter
## Cuánto pesa estar de frente contra estar cerca (0 = solo distancia).
@export_range(0.0, 1.0) var facing_weight := 0.6


func _init() -> void:
	collision_layer = 0
	collision_mask = Interactable.LAYER
	monitorable = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"interact") or not player.can_interact():
		return
	var target := best()
	if target:
		target.interact(player)
		get_viewport().set_input_as_handled()


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
		var score := -to.length() + facing_weight * to.normalized().dot(forward) * 2.0
		if score > best_score:
			best_score = score
			chosen = interactable
	return chosen
