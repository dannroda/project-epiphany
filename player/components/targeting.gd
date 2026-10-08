class_name Targeting
extends Node
## Lock-on (Z-target) y cambio de objetivo con el stick derecho.

signal target_changed(target: Node3D)

enum LockMode { HOLD, TOGGLE }

@export var player: PlayerCharacter
@export var target_indicator: TargetIndicator
@export var lock_mode: LockMode = LockMode.HOLD
@export var targeting_range: float = 12.0
@export var detector_shape: CollisionShape3D

@export_group("Cambio de objetivo")
## Umbral del stick para saltar; apuntar (Aim) usa la zona muerta normal.
@export var switch_threshold := 0.7
## Cono hacia la dirección pedida (0.5 ≈ ±60°).
@export var min_alignment := 0.5
## Sin candidato en esa dirección: saltar al del otro extremo.
@export var wrap_around := false
## Cuánto se espera antes de soltar un objetivo que murió o salió de rango.
@export var lose_grace := 0.5

var current: Node3D
var possible_targets: Array[Node3D] = []

var _last_dir := Vector2.ZERO
var _invalid_time := 0.0


func _ready() -> void:
	_set_range(targeting_range)


func _unhandled_input(event: InputEvent) -> void:
	if current and event.is_action_pressed(&"target_prev"):
		cycle(Vector2.LEFT)
	elif current and event.is_action_pressed(&"target_next"):
		cycle(Vector2.RIGHT)
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


func _physics_process(delta: float) -> void:
	_check_current(delta)
	if current == null:
		_last_dir = Vector2.ZERO
		return
	var dir := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down", switch_threshold)
	if dir != Vector2.ZERO and _last_dir == Vector2.ZERO:
		cycle(dir.normalized())
	_last_dir = dir


func lock_best_target() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var candidates := valid_candidates(camera)
	if candidates.is_empty():
		clear()
		return
	set_target(_most_centered(candidates, camera))


## Salta al candidato mejor alineado con `screen_dir` (espacio de pantalla, +y hacia abajo).
func cycle(screen_dir: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or current == null:
		return
	var from := camera.unproject_position(current.global_position)
	var best: Node3D = null
	var best_score := -INF
	var opposite: Node3D = null
	var opposite_score := INF
	for candidate in valid_candidates(camera):
		if candidate == current:
			continue
		var offset := camera.unproject_position(candidate.global_position) - from
		var alignment := offset.normalized().dot(screen_dir)
		if alignment >= min_alignment:
			var score := alignment * 2.0 - offset.length() / 500.0
			if score > best_score:
				best_score = score
				best = candidate
		elif alignment - offset.length() / 500.0 < opposite_score:
			opposite_score = alignment - offset.length() / 500.0
			opposite = candidate
	if best == null and wrap_around:
		best = opposite
	if best:
		set_target(best)
		Feel.sfx(&"click", player.global_position)


## En rango, en pantalla, fijable y a la vista (el rayo solo choca con el mundo).
func valid_candidates(camera: Camera3D) -> Array[Node3D]:
	var screen := get_viewport().get_visible_rect()
	var result: Array[Node3D] = []
	for candidate in possible_targets:
		if not is_instance_valid(candidate) or not candidate.is_in_group(&"targetable"):
			continue
		if camera.is_position_behind(candidate.global_position):
			continue
		if not screen.has_point(camera.unproject_position(candidate.global_position)):
			continue
		if _in_sight(candidate):
			result.append(candidate)
	return result


func set_target(target: Node3D) -> void:
	if target == current:
		return
	current = target
	_invalid_time = 0.0
	if target_indicator:
		target_indicator.set_target(target)
	if target:
		Log.debug(&"targeting", "Fijado:", target.name)
	target_changed.emit(target)


func clear() -> void:
	set_target(null)


func _check_current(delta: float) -> void:
	if current == null:
		return
	if is_instance_valid(current) and current.is_in_group(&"targetable") and possible_targets.has(current):
		_invalid_time = 0.0
		return
	_invalid_time += delta
	if is_instance_valid(current) and _invalid_time < lose_grace:
		return
	if lock_mode == LockMode.TOGGLE:
		var lost := current
		current = null
		lock_best_target()
		if current == lost:
			clear()
	else:
		clear()


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
	var exclude: Array[RID] = [player.get_rid()]
	for candidate in possible_targets:
		if is_instance_valid(candidate) and candidate is CollisionObject3D:
			exclude.append(candidate.get_rid())
	query.exclude = exclude
	query.collision_mask = 1
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


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
