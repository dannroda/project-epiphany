@tool
class_name Chest
extends StaticBody3D

const OPEN_ANGLE := -110.0
const BIG_BASE := preload("res://assets/epiphany/meshes/objetos/cofre_grande.res")
const BIG_LID := preload("res://assets/epiphany/meshes/objetos/cofre_grande_tapa.res")
## Bisagra de la tapa del arca sobre su base (la tapa tiene el origen ahí).
const BIG_HINGE := Vector3(0.0, 0.65, -0.475)
const BIG_SCALE := 1.4

@export var item: ItemData
@export var amount: int = 1
@export var flag: StringName: ## p. ej. &"d1_chest_bow"
	set(value):
		flag = value
		update_configuration_warnings()
@export var big: bool = false ## Cofre grande: ítem de la mazmorra / llave del jefe

@onready var interactable: Interactable = $Interactable
## La tapa (gira sobre la bisagra de atrás).
@onready var lid: MeshInstance3D = $Model/Lid

var persistent: PersistentFlag


func _ready() -> void:
	if big:
		_make_big()
	if Engine.is_editor_hint():
		return
	add_to_group(&"chests")
	if big:
		scale = Vector3.ONE * BIG_SCALE
	persistent = $PersistentFlag
	persistent.flag = flag
	persistent.changed.connect(func(opened: Variant) -> void: _show(opened == true))
	_show(persistent.value == true)
	interactable.interacted.connect(_open)


func _get_configuration_warnings() -> PackedStringArray:
	return PersistentFlag.warnings_for(flag, false)


func _open(by: PlayerCharacter) -> void:
	interactable.enabled = false
	persistent.value = true
	GameState.give(item, amount)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(lid, "rotation_degrees:x", OPEN_ANGLE, 0.35)
	Feel.sfx(&"click", global_position)
	by.play_item_get(item, amount)
	if big:
		SaveManager.autosave.call_deferred()


## Sin animación: al entrar a la escena o al cargar una partida.
func _show(opened: bool) -> void:
	if opened == not interactable.enabled:
		return
	interactable.enabled = not opened
	lid.rotation_degrees.x = OPEN_ANGLE if opened else 0.0


## El arca de piedra ya viene grande: se compensa la escala del cuerpo.
func _make_big() -> void:
	($Model/Base as MeshInstance3D).mesh = BIG_BASE
	lid.mesh = BIG_LID
	lid.position = BIG_HINGE
	if not Engine.is_editor_hint():
		$Model.scale = Vector3.ONE / BIG_SCALE
