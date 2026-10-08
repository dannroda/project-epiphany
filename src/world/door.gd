@tool
class_name Door
extends StaticBody3D
## Puerta de mazmorra. La hoja se hunde al abrirse (la colisión se apaga al terminar) y sube al cerrarse.
## LOCKED/BOSS se abren con llave al interactuar y quedan abiertas por su flag; SHUTTER la cierra su Room
## mientras tenga enemigos; SWITCH la abre la señal `activated` de un interruptor.

signal opened
signal closed

enum Kind { OPEN, LOCKED, SHUTTER, SWITCH, BOSS }

const COLORS := {
	Kind.OPEN: Color(0.5, 0.48, 0.45),
	Kind.LOCKED: Color(0.45, 0.32, 0.2),
	Kind.SHUTTER: Color(0.3, 0.3, 0.33),
	Kind.SWITCH: Color(0.4, 0.42, 0.5),
	Kind.BOSS: Color(0.45, 0.12, 0.12),
}
const TEXTS: DialogueResource = preload("res://data/dialogue/doors.dialogue")

@export var kind: Kind = Kind.OPEN:
	set(value):
		kind = value
		update_configuration_warnings()
## Persistencia para LOCKED / BOSS.
@export var flag: StringName:
	set(value):
		flag = value
		update_configuration_warnings()
## SHUTTER: la sala que la cierra mientras tenga enemigos.
@export var room: Room
## SWITCH: el nodo con la señal `activated` (y `deactivated` si no se queda abierta).
@export var switch: Node
@export var stays_open := true
@export var open_time := 0.5

@onready var leaf: Node3D = %Leaf
@onready var shape: CollisionShape3D = $CollisionShape3D
@onready var interactable: Interactable = $Interactable

var is_open := false
var _closed_y := 0.0
var _tween: Tween
var _persistent: PersistentFlag


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(&"doors")
	_closed_y = leaf.position.y
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORS[kind]
	for mesh in leaf.find_children("*", "MeshInstance3D", true, false):
		if mesh != %Lock:
			(mesh as MeshInstance3D).material_override = material
	%Lock.visible = kind in [Kind.LOCKED, Kind.BOSS]
	interactable.enabled = false
	match kind:
		Kind.OPEN, Kind.SHUTTER:
			open(false)
		Kind.LOCKED, Kind.BOSS:
			interactable.enabled = true
			interactable.interacted.connect(func(_by: PlayerCharacter) -> void: try_unlock())
			_persistent = PersistentFlag.new()
			_persistent.flag = flag
			_persistent.changed.connect(func(value: Variant) -> void:
				if value == true:
					open(false)
				else:
					close(false)
				interactable.enabled = value != true)
			add_child(_persistent)
			if _persistent.value == true:
				open(false)
				interactable.enabled = false
		Kind.SWITCH:
			if switch:
				switch.connect(&"activated", open)
				if not stays_open and switch.has_signal(&"deactivated"):
					switch.connect(&"deactivated", close)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PersistentFlag.warnings_for(flag, kind not in [Kind.LOCKED, Kind.BOSS])
	if kind == Kind.SHUTTER and room == null:
		warnings.append("Una persiana necesita su Room.")
	if kind == Kind.SWITCH and switch == null:
		warnings.append("Una puerta con interruptor necesita el nodo que emite `activated`.")
	return warnings


## Con llave: gasta una llave chica (LOCKED) o pide la del jefe (BOSS).
func try_unlock() -> bool:
	if is_open:
		return true
	var dungeon := GameState.current_dungeon_state()
	match kind:
		Kind.LOCKED:
			if dungeon.small_keys <= 0:
				_refuse(&"locked")
				return false
			dungeon.small_keys -= 1
		Kind.BOSS:
			if not dungeon.has_boss_key:
				_refuse(&"boss_locked")
				return false
		_:
			return false
	interactable.enabled = false
	_persistent.value = true
	open(true)
	return true


func open(animate: bool = true) -> void:
	if is_open:
		return
	is_open = true
	_move_leaf(_closed_y - 2.5, animate, true)
	opened.emit()


func close(animate: bool = true) -> void:
	if not is_open:
		return
	is_open = false
	shape.set_deferred(&"disabled", false)
	_move_leaf(_closed_y, animate, false)
	closed.emit()


func _move_leaf(y: float, animate: bool, opening: bool) -> void:
	if _tween:
		_tween.kill()
	if not animate:
		leaf.position.y = y
		shape.set_deferred(&"disabled", opening)
		return
	Feel.sfx(&"door", global_position)
	Feel.burst(&"dust", global_position + Vector3.UP * 0.1, Vector3.UP)
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(leaf, "position:y", y, open_time)
	if opening:
		_tween.tween_callback(func() -> void: shape.set_deferred(&"disabled", true))


func _refuse(cue: StringName) -> void:
	Feel.sfx(&"deny", global_position)
	TextBox.open(TEXTS, cue)
