@tool
class_name EyeSwitch
extends StaticBody3D
## Ojo de piedra que solo reacciona a proyectiles (flechas, orbes reflejados). Con flag queda abierto entre partidas.

signal activated
signal deactivated

const CLOSED := Color(0.55, 0.5, 0.6)
const OPEN := Color(1.0, 0.78, 0.3)

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
var _material := StandardMaterial3D.new()


func _ready() -> void:
	_material.albedo_texture = preload("res://assets/epiphany/palette.png")
	_material.roughness = 0.4
	_material.emission_enabled = true
	eye.material_override = _material
	_show(false)
	if Engine.is_editor_hint():
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


func _get_configuration_warnings() -> PackedStringArray:
	return PersistentFlag.warnings_for(flag, true)


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
	_material.albedo_color = OPEN if open else CLOSED
	_material.emission = OPEN if open else Color.BLACK
	_material.emission_energy_multiplier = 1.5 if open else 0.0
	gem.visible = open
	glow.visible = open
