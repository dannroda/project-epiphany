@tool
class_name EyeSwitch
extends StaticBody3D
## Ojo de piedra que solo reacciona a proyectiles (flechas, orbes reflejados). Con flag queda abierto entre partidas.

signal activated
signal deactivated

const CLOSED := Color(0.85, 0.82, 0.9)
const OPEN := Color(1.25, 1.15, 1.0)
## Los valores por defecto de epiphany_outdoor.gdshader.
const GLOW := 1.5
const ALBEDO := Color(0.72, 0.72, 0.72)
const LOOK_RANGE := 10.0
const LOOK_LIMIT := deg_to_rad(40.0)
const LOOK_SPEED := 6.0

@export var flag: StringName:
	set(value):
		flag = value
		update_configuration_warnings()
## Con tiempo: se apaga solo a los tantos segundos (sin flag; se vuelve a flechar).
@export var open_time := 0.0

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var eye: MeshInstance3D = %Eye
@onready var gem: MeshInstance3D = %Gem
@onready var glow: OmniLight3D = %Glow

var active := false
var _persistent: PersistentFlag
var _material: ShaderMaterial
var _rest: Quaternion


func _ready() -> void:
	_material = eye.mesh.surface_get_material(0).duplicate()
	eye.material_override = _material
	_rest = eye.quaternion
	_show(false)
	if Engine.is_editor_hint():
		set_process(false)
		return
	hurtbox.hit.connect(_on_hit)
	if flag != &"":
		_persistent = $PersistentFlag
		_persistent.flag = flag
		_persistent.changed.connect(func(value: Variant) -> void:
			var was := active
			_show(value == true)
			if active and not was:
				activated.emit())
		_show(_persistent.value == true)


func _process(delta: float) -> void:
	var goal := _rest
	var player := Players.nearest(eye.global_position)
	if not active and player and player.global_position.distance_to(eye.global_position) < LOOK_RANGE:
		var to := eye.get_parent_node_3d().global_basis.inverse() * (player.global_position + Vector3.UP * 0.8 - eye.global_position)
		var ahead := _rest * Vector3.BACK
		var turn := Quaternion(ahead, to.normalized()) if not to.is_zero_approx() else Quaternion.IDENTITY
		var angle := turn.get_angle()
		if angle > LOOK_LIMIT:
			turn = Quaternion.IDENTITY.slerp(turn, LOOK_LIMIT / angle)
		goal = turn * _rest
	eye.quaternion = eye.quaternion.slerp(goal, 1.0 - exp(-LOOK_SPEED * delta))


func _get_configuration_warnings() -> PackedStringArray:
	return PersistentFlag.warnings_for(flag, true, self)


func _on_hit(info: DamageInfo) -> void:
	if active or not info.source is Projectile:
		return
	_show(true)
	if _persistent:
		_persistent.value = true
	Feel.sfx(&"reflect", global_position)
	Feel.burst(&"sparks", eye.global_position, Vector3.UP)
	activated.emit()
	if open_time > 0.0:
		_count_down()


func _count_down() -> void:
	var left := open_time
	while left > 0.0:
		var step := minf(left, 1.0 if left > 2.0 else 0.5)
		await get_tree().create_timer(step, false).timeout
		left -= step
		if left > 0.0:
			Feel.sfx(&"click", global_position)
	_show(false)
	Feel.sfx(&"block", global_position)
	deactivated.emit()


func _show(open: bool) -> void:
	active = open
	_material.set_shader_parameter(&"albedo_color", ALBEDO * (OPEN if open else CLOSED))
	_material.set_shader_parameter(&"emission_energy", GLOW * (2.0 if open else 0.4))
	gem.visible = open
	glow.visible = open
