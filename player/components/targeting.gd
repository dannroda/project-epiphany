class_name Targeting
extends Node
## Lock-on (Z-target). El cambio de objetivo es M2.

signal target_changed(target: Node3D)

enum LockMode { HOLD, TOGGLE }

@export var player: PlayerCharacter
@export var target_indicator: TargetIndicator
@export var lock_mode: LockMode = LockMode.HOLD
@export var targeting_range: float = 12.0
@export var detector_shape: CollisionShape3D

var current: Node3D
var possible_targets: Array[Node3D] = []


func _ready() -> void:
	_set_range(targeting_range)


func _unhandled_input(event: InputEvent) -> void:
	if lock_mode == LockMode.HOLD:
		if event.is_action_pressed(&"z-lock"):
			lock_best_target()
		elif event.is_action_released(&"z-lock"):
			clear()
	elif event.is_action_pressed(&"z-lock"):
		if current:
			clear()
		else:
			lock_best_target()


func _physics_process(_delta: float) -> void:
	if current and (not is_instance_valid(current) or not possible_targets.has(current) or not current.is_in_group(&"targetable")):
		clear()


func lock_best_target() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var candidates: Array[Node3D] = []
	for candidate in possible_targets:
		if is_instance_valid(candidate) and candidate.is_in_group(&"targetable") and not camera.is_position_behind(candidate.global_position) and _in_sight(candidate):
			candidates.append(candidate)
	if candidates.is_empty():
		clear()
		return
	set_target(_most_centered(candidates, camera))


func set_target(target: Node3D) -> void:
	if target == current:
		return
	current = target
	if target_indicator:
		target_indicator.set_target(target)
	if target:
		Log.debug(&"targeting", "Fijado:", target.name)
	target_changed.emit(target)


func clear() -> void:
	set_target(null)


func _most_centered(candidates: Array[Node3D], camera: Camera3D) -> Node3D:
	var center := get_viewport().get_visible_rect().size / 2.0
	var best: Node3D = null
	var best_distance := INF
	for candidate in candidates:
		var distance := camera.unproject_position(candidate.global_position).distance_to(center)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _in_sight(target: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP, target.global_position + Vector3.UP)
	query.exclude = [player.get_rid()]
	query.collision_mask = 1
	var result := player.get_world_3d().direct_space_state.intersect_ray(query)
	return result.is_empty() or result.collider == target


func _set_range(radius: float) -> void:
	if not detector_shape or not detector_shape.shape:
		return
	if not detector_shape.shape.resource_local_to_scene:
		detector_shape.shape = detector_shape.shape.duplicate()
	var cylinder := detector_shape.shape as CylinderShape3D
	if cylinder:
		cylinder.radius = radius


func _on_detector_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"targetable"):
		possible_targets.append(body)


func _on_detector_body_exited(body: Node3D) -> void:
	possible_targets.erase(body)
	if body == current:
		clear()
