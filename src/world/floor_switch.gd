@tool
class_name FloorSwitch
extends Area3D
## Interruptor de piso.
## HOLD: activo mientras haya algo encima (player, bloque u objeto). ONCE: lo que sea lo deja activado (y, con flag, entre partidas).
## BLOCK: solo un bloque empujable; queda resuelto. WEIGHT: un objeto apoyado o arrojado (o un bloque); queda resuelto.
## STRIKE: un golpe fuerte (DamageInfo.strong, el martillazo) sobre la placa; queda resuelto. Pisarla no hace nada.
## El player no aprieta ni BLOCK ni WEIGHT.

signal activated
signal deactivated

enum Mode { HOLD, ONCE, BLOCK, WEIGHT, STRIKE }

const HURTBOX_LAYER := 16

@export var mode: Mode = Mode.HOLD:
	set(value):
		mode = value
		_apply_look()
## Marco y placa de BLOCK: con la chakana del bloque, para que no se confunda con la que pisa el player.
@export var block_frame: Mesh
@export var block_plate: Mesh
## Marco y placa de STRIKE: cobre con el estallido.
@export var strike_frame: Mesh
@export var strike_plate: Mesh
@export var flag: StringName:
	set(value):
		flag = value
		update_configuration_warnings()

@onready var plate: Node3D = %Plate

var active := false
var _plate_y := 0.0
var _persistent: PersistentFlag
var _solved := false
var _look: Array[Mesh] = []


func _ready() -> void:
	_apply_look()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	_plate_y = plate.position.y
	collision_layer = 0
	collision_mask = 1 | 8
	monitorable = false
	var hurtbox := $Hurtbox as Hurtbox
	if mode == Mode.STRIKE:
		hurtbox.collision_layer = HURTBOX_LAYER
		hurtbox.hit.connect(_on_hit)
		set_physics_process(false)
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


func _apply_look() -> void:
	if plate == null:
		return
	var model := $Model as MeshInstance3D
	if _look.is_empty():
		_look = [model.mesh, (plate as MeshInstance3D).mesh]
	var look: Array = _look
	if mode == Mode.BLOCK and block_plate:
		look = [block_frame, block_plate]
	elif mode == Mode.STRIKE and strike_plate:
		look = [strike_frame, strike_plate]
	model.mesh = look[0]
	(plate as MeshInstance3D).mesh = look[1]


func _get_configuration_warnings() -> PackedStringArray:
	return PersistentFlag.warnings_for(flag, true, self)


func _physics_process(_delta: float) -> void:
	var pressed := get_overlapping_bodies().any(_presses)
	if pressed and not active:
		_set_active(true, true)
	elif not pressed and active and mode == Mode.HOLD:
		_set_active(false, true)
	if pressed and mode != Mode.HOLD and not _solved:
		_solved = true
		if _persistent:
			_persistent.value = true
	if active and _solved and mode != Mode.HOLD:
		set_physics_process(false)


func _on_hit(info: DamageInfo) -> void:
	if not info.strong or _solved:
		return
	_solved = true
	if _persistent:
		_persistent.value = true
	_set_active(true, true)
	Feel.shake(0.15)


func _presses(body: Node3D) -> bool:
	match mode:
		Mode.STRIKE:
			return false
		Mode.BLOCK:
			return body is PushBlock
		Mode.WEIGHT:
			return body is PushBlock or body is RigidBody3D
	return body is PlayerCharacter or body is PushBlock or body is RigidBody3D


func _set_active(on: bool, announce: bool) -> void:
	active = on
	if not on:
		set_physics_process(true)
	plate.position.y = _plate_y - (0.06 if on else 0.0)
	if announce:
		Feel.sfx(&"click", global_position)
	if on:
		activated.emit()
	else:
		deactivated.emit()
