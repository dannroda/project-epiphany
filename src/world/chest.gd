@tool
class_name Chest
extends StaticBody3D

const GROUP := &"chests"
const OPEN_ANGLE := -110.0
const BIG_BASE := preload("res://assets/epiphany/meshes/objetos/cofre_grande.res")
const BIG_LID := preload("res://assets/epiphany/meshes/objetos/cofre_grande_tapa.res")
## Bisagra de la tapa del arca sobre su base (la tapa tiene el origen ahí).
const BIG_HINGE := Vector3(0.0, 0.65, -0.475)
const BIG_SCALE := 1.4
## Lo que dice si no tiene dónde guardar el contenido (cue `missing_<id>` del ítem que le falta).
const TEXTS: DialogueResource = preload("res://data/dialogue/item_get.dialogue")

@export var item: ItemData
@export var amount: int = 1
@export var flag: StringName: ## p. ej. &"d1_chest_bow"
	set(value):
		flag = value
		update_configuration_warnings()
@export var big: bool = false ## Cofre grande: ítem de la mazmorra / llave del jefe
## Aparece recién cuando se cumplen (p. ej. al vencer una oleada).
@export var switches: Array[NodePath] = []

@onready var interactable: Interactable = $Interactable
## La tapa (gira sobre la bisagra de atrás).
@onready var lid: MeshInstance3D = $Model/Lid

var persistent: PersistentFlag
var _wiring: Wiring
var _layer := 0


func _ready() -> void:
	if big:
		_make_big()
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	if big:
		scale = Vector3.ONE * BIG_SCALE
	persistent = $PersistentFlag
	persistent.flag = flag
	persistent.changed.connect(func(opened: Variant) -> void: _show(opened == true))
	_show(persistent.value == true)
	interactable.interacted.connect(_open)
	if not switches.is_empty() and persistent.value != true:
		_hide()
		_wiring = Wiring.create(self, switches, Wiring.Condition.ALL)
		_wiring.settled.connect(func(ok: bool) -> void:
			if ok:
				_appear(false))
		_wiring.changed.connect(func(ok: bool) -> void:
			if ok:
				_appear(true))


func _hide() -> void:
	visible = false
	_layer = collision_layer
	collision_layer = 0
	interactable.enabled = false


func _appear(announce: bool) -> void:
	if visible:
		return
	visible = true
	collision_layer = _layer
	interactable.enabled = true
	if announce:
		Feel.burst(&"dust", global_position + Vector3.UP * 0.3, Vector3.UP)
		Feel.sfx(&"secret", global_position)


func _get_configuration_warnings() -> PackedStringArray:
	return PersistentFlag.warnings_for(flag, false, self)


func _open(by: PlayerCharacter) -> void:
	var holder := GameState.missing_holder(item)
	if holder:
		Feel.sfx(&"deny", global_position)
		TextBox.open(TEXTS, "missing_" + holder.id)
		return
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
	if not visible:
		if not opened:
			return
		_appear(false)
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
