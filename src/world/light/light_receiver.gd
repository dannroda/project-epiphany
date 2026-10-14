@tool
class_name LightReceiver
extends StaticBody3D
## Cristal: se enciende mientras lo toca un LightBeam. Con `latch` queda encendido (y, con flag, entre partidas).

signal activated
signal deactivated

@export var latch := false
@export var flag: StringName:
	set(value):
		flag = value
		update_configuration_warnings()

@onready var crystal: MeshInstance3D = %Crystal

var lit := false
## Interfaz común de interruptores (Wiring).
var active: bool:
	get:
		return lit
var _last_light := -10
var _material := StandardMaterial3D.new()
var _persistent: PersistentFlag


func _ready() -> void:
	_material.albedo_color = Color(0.55, 0.75, 0.95, 0.85)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.emission_enabled = true
	_material.emission = Color(1.0, 0.9, 0.55)
	crystal.material_override = _material
	_show(false)
	if Engine.is_editor_hint() or flag == &"":
		return
	_persistent = $PersistentFlag
	_persistent.flag = flag
	_persistent.changed.connect(func(value: Variant) -> void:
		if value == true and not lit:
			_set_lit(true, false))
	if _persistent.value == true:
		_set_lit(true, false)


func _get_configuration_warnings() -> PackedStringArray:
	return PersistentFlag.warnings_for(flag, true, self)


## La llama el haz cada cuadro que lo toca.
func receive_light() -> void:
	_last_light = Engine.get_physics_frames()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var touched := Engine.get_physics_frames() - _last_light <= 1
	if touched and not lit:
		_set_lit(true, true)
	elif not touched and lit and not latch:
		_set_lit(false, true)


func _set_lit(on: bool, announce: bool) -> void:
	lit = on
	_show(on)
	if on and _persistent and latch:
		_persistent.value = true
	if on:
		if announce:
			Feel.sfx(&"secret" if latch else &"reflect", global_position)
		activated.emit()
	else:
		deactivated.emit()


func _show(on: bool) -> void:
	_material.emission_energy_multiplier = 3.0 if on else 0.15
