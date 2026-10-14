@tool
class_name Tablet
extends StaticBody3D
## Tablilla de piedra: "Leer" abre su cue de Dialogue Manager. El flag es opcional (pistas de puzzle que el mapa puede marcar).

@export var dialogue: DialogueResource
@export var cue: String = ""
@export var flag: StringName:
	set(value):
		flag = value
		update_configuration_warnings()

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	interactable.interacted.connect(_read)


func _get_configuration_warnings() -> PackedStringArray:
	return PersistentFlag.warnings_for(flag, true, self)


func is_read() -> bool:
	return flag != &"" and GameState.get_flag(flag) == true


func _read(_by: PlayerCharacter) -> void:
	if flag != &"":
		GameState.set_flag(flag, true)
	TextBox.open(dialogue, cue)
