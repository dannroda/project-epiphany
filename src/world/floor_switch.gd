@tool
class_name FloorSwitch
extends Area3D
## Interruptor de piso: lo activa el player, un bloque o un cuerpo físico encima.
## HOLD: activo mientras haya algo encima. ONCE: queda activado (y, con flag, entre partidas).
## BLOCK: el player lo activa solo mientras está encima; un bloque o algo arrojado lo deja activado como ONCE.

signal activated
signal deactivated

enum Mode { HOLD, ONCE, BLOCK }

@export var mode: Mode = Mode.HOLD
@export var flag: StringName:
	set(value):
		flag = value
		update_configuration_warnings()

@onready var plate: Node3D = %Plate

var active := false
var _plate_y := 0.0
var _persistent: PersistentFlag
var _solved := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_plate_y = plate.position.y
	collision_layer = 0
	collision_mask = 1 | 8
	monitorable = false
	if flag != &"":
		_persistent = PersistentFlag.new()
		_persistent.flag = flag
		_persistent.changed.connect(func(value: Variant) -> void:
			if value == true:
				_solved = true
				if not active:
					_set_active(true, false))
		add_child(_persistent)
		if _persistent.value == true:
			_solved = true
			_set_active(true, false)


func _get_configuration_warnings() -> PackedStringArray:
	return PersistentFlag.warnings_for(flag, true)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var bodies := get_overlapping_bodies()
	var pressed := bodies.any(func(body: Node3D) -> bool:
		return body is PlayerCharacter or body is PushBlock or body is RigidBody3D)
	if mode == Mode.BLOCK and not _solved and bodies.any(func(body: Node3D) -> bool: return body is PushBlock or body is RigidBody3D):
		_solved = true
		if _persistent:
			_persistent.value = true
	if pressed and not active:
		_set_active(true, true)
	elif not pressed and active and _releases():
		_set_active(false, true)


func _releases() -> bool:
	return mode == Mode.HOLD or (mode == Mode.BLOCK and not _solved)


func _set_active(on: bool, announce: bool) -> void:
	active = on
	plate.position.y = _plate_y - (0.06 if on else 0.0)
	if on and _persistent and mode == Mode.ONCE:
		_persistent.value = true
	if announce:
		Feel.sfx(&"click", global_position)
	if on:
		activated.emit()
	else:
		deactivated.emit()
