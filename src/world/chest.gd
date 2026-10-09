@tool
class_name Chest
extends StaticBody3D

const OPEN_ANGLE := -110.0
const MODEL := preload("res://assets/kaykit_dungeon/chest.glb")
const BIG_MODEL := preload("res://assets/kaykit_dungeon/chest_gold.glb")
const MODEL_SCALE := 0.6

@export var item: ItemData
@export var amount: int = 1
@export var flag: StringName: ## p. ej. &"d1_chest_bow"
	set(value):
		flag = value
		update_configuration_warnings()
@export var big: bool = false ## Cofre grande: ítem de la mazmorra / llave del jefe

@onready var interactable: Interactable = $Interactable

## La tapa del modelo de KayKit (gira sobre la bisagra de atrás).
var lid: Node3D
var persistent: PersistentFlag


func _ready() -> void:
	_build_model()
	if Engine.is_editor_hint():
		return
	add_to_group(&"chests")
	if big:
		scale = Vector3.ONE * 1.4
	persistent = PersistentFlag.new()
	persistent.flag = flag
	persistent.changed.connect(func(opened: Variant) -> void: _show(opened == true))
	add_child(persistent)
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


## Modelo de KayKit Dungeon (el dorado para los grandes); sin owner, así no se guarda en la escena.
func _build_model() -> void:
	var model: Node3D = (BIG_MODEL if big else MODEL).instantiate()
	model.name = "Model"
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model, false, INTERNAL_MODE_FRONT)
	lid = model.find_children("*_lid", "Node3D", true, false)[0]

