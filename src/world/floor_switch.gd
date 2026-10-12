@tool
class_name FloorSwitch
extends Area3D
## Interruptor de piso.
## HOLD: activo mientras haya algo encima (player, bloque u objeto). ONCE: lo que sea lo deja activado (y, con flag, entre partidas).
## BLOCK: solo un bloque empujable; queda resuelto. WEIGHT: un objeto apoyado o arrojado (o un bloque); queda resuelto.
## El player no aprieta ni BLOCK ni WEIGHT.

signal activated
signal deactivated

enum Mode { HOLD, ONCE, BLOCK, WEIGHT }

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
		_persistent = $PersistentFlag
		_persistent.flag = flag
		_persistent.changed.connect(func(value: Variant) -> void:
			if value == true:
				_solved = true
				if not active:
					_set_active(true, false))
		if _persistent.value == true:
			_solved = true
			_set_active(true, false)


func _get_configuration_warnings() -> PackedStringArray:
	return PersistentFlag.warnings_for(flag, true)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var pressed := get_overlapping_bodies().any(_presses)
	if pressed and not active:
		_set_active(true, true)
	elif not pressed and active and mode == Mode.HOLD:
		_set_active(false, true)
	if pressed and mode != Mode.HOLD and not _solved:
		_solved = true
		if _persistent:
			_persistent.value = true


func _presses(body: Node3D) -> bool:
	match mode:
		Mode.BLOCK:
			return body is PushBlock
		Mode.WEIGHT:
			return body is PushBlock or body is RigidBody3D
	return body is PlayerCharacter or body is PushBlock or body is RigidBody3D


func _set_active(on: bool, announce: bool) -> void:
	active = on
	plate.position.y = _plate_y - (0.06 if on else 0.0)
	if announce:
		Feel.sfx(&"click", global_position)
	if on:
		activated.emit()
	else:
		deactivated.emit()
