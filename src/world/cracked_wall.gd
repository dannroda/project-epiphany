@tool
class_name CrackedWall
extends StaticBody3D
## Pared con grietas: solo una explosión la rompe. Queda rota entre partidas por su flag.

signal broken

@export var flag: StringName:
	set(value):
		flag = value
		update_configuration_warnings()

@onready var wall: Node3D = %Wall
@onready var rubble: Node3D = %Rubble
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var shape: CollisionShape3D = $CollisionShape3D

var is_broken := false
var _persistent: PersistentFlag


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	hurtbox.hit.connect(_on_hit)
	_persistent = $PersistentFlag
	_persistent.flag = flag
	_persistent.changed.connect(func(value: Variant) -> void: _show(value == true))
	_show(_persistent.value == true)


func _get_configuration_warnings() -> PackedStringArray:
	return PersistentFlag.warnings_for(flag, false)


func _on_hit(info: DamageInfo) -> void:
	if is_broken:
		return
	if info.element != &"explosive":
		Feel.burst(&"sparks", hurtbox.global_position, Vector3.UP)
		Feel.sfx(&"hit_stone", global_position)
		return
	_show(true)
	_persistent.value = true
	Feel.burst(&"dust", global_position + Vector3.UP * 1.0, Vector3.UP)
	Feel.burst(&"shards", global_position + Vector3.UP * 1.2, Vector3.UP)
	Feel.sfx(&"secret", global_position)
	Feel.shake(Feel.settings.shake_give * 2.0)
	broken.emit()


## Sin efectos: al entrar a la escena o al cargar una partida.
func _show(open: bool) -> void:
	is_broken = open
	wall.visible = not open
	rubble.visible = open
	shape.set_deferred(&"disabled", open)
	hurtbox.set_deferred(&"monitorable", not open)
