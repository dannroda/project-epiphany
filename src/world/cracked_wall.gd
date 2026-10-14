@tool
class_name CrackedWall
extends StaticBody3D
## Pared con grietas: solo una explosión la rompe. Queda rota entre partidas por su flag.
## Con `switches` no la rompe una explosión sino sus interruptores (el piso que rompe un sub-jefe al caer).
## `covers`: techos que tapan lo que esconde hasta que se rompe; al romperse se ocultan y se apagan (con su piso, si tienen).

signal broken

@export var flag: StringName:
	set(value):
		flag = value
		update_configuration_warnings()
@export var switches: Array[NodePath] = []
@export var condition: Wiring.Condition = Wiring.Condition.ALL
@export var covers: Array[NodePath] = []

@onready var wall: Node3D = %Wall
@onready var rubble: Node3D = %Rubble
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var shape: CollisionShape3D = $CollisionShape3D

var is_broken := false
var _persistent: PersistentFlag
var _wiring: Wiring
var _shake_tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	hurtbox.hit.connect(_on_hit)
	_persistent = $PersistentFlag
	_persistent.flag = flag
	_persistent.changed.connect(func(value: Variant) -> void: _show(value == true))
	_show(_persistent.value == true)
	if not switches.is_empty():
		_wiring = Wiring.create(self, switches, condition)
		_wiring.changed.connect(func(satisfied: bool) -> void:
			if satisfied:
				smash())
		_wiring.settled.connect(func(satisfied: bool) -> void:
			if satisfied:
				_show(true))


func _get_configuration_warnings() -> PackedStringArray:
	return PersistentFlag.warnings_for(flag, false, self)


func _on_hit(info: DamageInfo) -> void:
	if is_broken:
		return
	if info.element == &"dash":
		_shake()
		return
	if info.element != &"explosive" or not switches.is_empty():
		Feel.burst(&"sparks", hurtbox.global_position, Vector3.UP)
		Feel.sfx(&"hit_stone", global_position)
		return
	smash()


func _shake() -> void:
	if _shake_tween and _shake_tween.is_running():
		return
	Feel.burst(&"dust", hurtbox.global_position, Vector3.UP)
	Feel.sfx(&"hit_stone", global_position)
	var rest := wall.position
	_shake_tween = create_tween()
	for offset: float in [0.06, -0.05, 0.03, 0.0]:
		_shake_tween.tween_property(wall, ^"position:x", rest.x + offset, 0.05)


func smash() -> void:
	if is_broken:
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
	for path in covers:
		var cover := get_node_or_null(path) as Node3D
		if cover:
			cover.visible = not open
			cover.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT)
