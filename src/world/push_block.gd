@tool
class_name PushBlock
extends AnimatableBody3D
## Bloque de grilla: el player lo empuja de a una celda. No entra en paredes, otros bloques ni enemigos.
## Al salir de su sala vuelve a su lugar, salvo que su flag diga que el puzzle está resuelto.

signal moved

const CELL := 2.0
const MASK := 1 | 4 | 8

@export var room: Room
## Puzzle resuelto: el bloque queda donde está (y en `solved_position` al volver a la escena).
@export var solved_flag: StringName:
	set(value):
		solved_flag = value
		update_configuration_warnings()
@export var solved_position: Vector3
@export var move_time := 0.35
## Cuánto hay que empujar contra el bloque antes de que se mueva.
@export var push_delay := 0.3

@onready var interactable: Interactable = get_node_or_null(^"Interactable")
@onready var shape: CollisionShape3D = $CollisionShape3D

var moving := false
var _start := Vector3.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_start = global_position
	if interactable:
		interactable.interacted.connect(func(by: PlayerCharacter) -> void:
			var facing := by.model.global_basis.z
			try_push(PushBlock.axis(facing)))
	if room == null:
		for node in get_tree().get_nodes_in_group(Room.GROUP):
			if (node as Room).contains(global_position):
				room = node
	if room:
		room.player_left.connect(func(_room: Room) -> void: reset_position())
	GameState.loaded.connect(_on_loaded)
	if is_solved():
		global_position = solved_position


func _get_configuration_warnings() -> PackedStringArray:
	return PersistentFlag.warnings_for(solved_flag, true)


static func axis(direction: Vector3) -> Vector3:
	if absf(direction.x) > absf(direction.z):
		return Vector3(signf(direction.x), 0.0, 0.0)
	return Vector3(0.0, 0.0, signf(direction.z))


func is_solved() -> bool:
	return solved_flag != &"" and GameState.get_flag(solved_flag) == true


## Resuelto, queda trabado en su placa; tampoco entra al hueco de una puerta (taparía la salida).
func can_move(direction: Vector3) -> bool:
	var target := global_position + direction * CELL
	if is_solved() or in_doorway(target) or not fits(target):
		return false
	var space := get_world_3d().direct_space_state
	# Las paredes CSG son mallas: la caja no las detecta, un rayo sí.
	var half := (shape.shape as BoxShape3D).size.x / 2.0
	var side := Vector3.UP.cross(direction).normalized()
	for height: float in [0.4, 1.4]:
		for lateral: float in [-half * 0.85, 0.0, half * 0.85]:
			var from := global_position + Vector3.UP * height + side * lateral
			var ray := PhysicsRayQueryParameters3D.create(from, from + direction * (CELL + half - 0.05), MASK, [get_rid()])
			if not space.intersect_ray(ray).is_empty():
				return false
	return has_floor(target)


func in_doorway(target: Vector3) -> bool:
	return get_tree().get_nodes_in_group(Door.GROUP).any(func(door: Node3D) -> bool:
		return Vector2(door.global_position.x - target.x, door.global_position.z - target.z).length() < CELL * 0.75)


## Nada sólido en el lugar que ocuparía en `target`.
func fits(target: Vector3, exclude: Array = []) -> bool:
	var box := BoxShape3D.new()
	box.size = (shape.shape as BoxShape3D).size * 0.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY, target + shape.position + Vector3.UP * 0.1)
	query.collision_mask = MASK
	query.exclude = [get_rid()] + exclude
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func has_floor(target: Vector3) -> bool:
	var floor_ray := PhysicsRayQueryParameters3D.create(target + Vector3.UP * 0.5, target + Vector3.DOWN * 0.5, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(floor_ray).is_empty()


func try_push(direction: Vector3) -> bool:
	if moving or direction.is_zero_approx() or not can_move(direction):
		if not moving:
			Feel.sfx(&"deny", global_position)
		return false
	moving = true
	Feel.sfx(&"door", global_position)
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "global_position", global_position + direction * CELL, move_time)
	tween.tween_callback(func() -> void:
		moving = false
		moved.emit())
	return true


## Al cargar una partida sin cambiar de escena: resuelto en su lugar final, si no en el de inicio.
func _on_loaded() -> void:
	if moving:
		return
	global_position = solved_position if is_solved() else _start


func reset_position() -> void:
	if is_solved() or moving:
		return
	global_position = _start
