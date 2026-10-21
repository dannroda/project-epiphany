class_name TechniqueStone
extends StaticBody3D
## Piedra de técnica (11.34): la primera lectura enseña `technique` (su flag) y muestra el cartel de técnica nueva;
## después lo vuelve a mostrar. Brilla mientras no se aprendió.

const SCREEN := preload("res://src/ui/item_get/technique_learned.tscn")

@export var technique: TechniqueData

@onready var interactable: Interactable = $Interactable
@onready var glow: AnimationPlayer = %Glow


func _ready() -> void:
	interactable.interacted.connect(_read)
	glow.play(&"RESET" if technique.is_learned() else &"idle")


func _read(_by: PlayerCharacter) -> void:
	if not technique.is_learned():
		GameState.set_flag(technique.flag, true)
		glow.play(&"RESET")
		Feel.sfx(&"secret", global_position)
	var screen := SCREEN.instantiate()
	screen.technique = technique
	MenuStack.push(screen)
