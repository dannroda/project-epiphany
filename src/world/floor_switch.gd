@tool
class_name FloorSwitch
extends Area3D
## Interruptor de piso: lo activa el player, un bloque o un cuerpo físico encima.
## HOLD: activo mientras haya algo encima. ONCE: queda activado (y, con flag, entre partidas).

signal activated
signal deactivated

enum Mode { HOLD, ONCE }

@export var mode: Mode = Mode.HOLD
@export var flag: StringName:
	set(value):
		flag = value
		update_configuration_warnings()

@onready var plate: Node3D = %Plate

var active := false
var _plate_y := 0.0
var _persistent: PersistentFlag


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
			if value == true and not active:
				_set_active(true, false))
		add_child(_persistent)
		if _persistent.value == true:
			_set_active(true, false)


func _get_configuration_warnings() -> PackedStringArray:
	return PersistentFlag.warnings_for(flag, true)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var pressed := get_overlapping_bodies().any(func(body: Node3D) -> bool:
		return body is PlayerCharacter or body is PushBlock or body is RigidBody3D)
	if pressed and not active:
		_set_active(true, true)
	elif not pressed and active and mode == Mode.HOLD:
		_set_active(false, true)


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
