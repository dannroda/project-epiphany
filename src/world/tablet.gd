class_name Tablet
extends StaticBody3D
## Tablilla de piedra: "Leer" abre su texto. El flag es opcional (pistas de puzzle que el mapa puede marcar).

@export var text: TextData
@export var flag: StringName

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.interacted.connect(_read)


func is_read() -> bool:
	return flag != &"" and GameState.get_flag(flag) == true


func _read(_by: PlayerCharacter) -> void:
	if flag != &"":
		GameState.set_flag(flag, true)
	TextBox.open(text)
