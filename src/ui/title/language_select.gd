extends Control
## Elegir idioma la primera vez que se abre el juego (mockup Language), arriba del título en el MenuStack.
## Mientras el foco pasa por una opción, la pantalla ya se ve en ese idioma.

signal chosen(language: String)

const SCENE_PATH := "res://src/ui/title/language_select.tscn"

var modal := true

@onready var options: Dictionary = {"es": %Spanish, "en": %English}


static func open() -> Control:
	var screen: Control = load(SCENE_PATH).instantiate()
	MenuStack.push(screen)
	return screen


func _ready() -> void:
	%Hints.hints = [[&"ui_accept", "HINT_ACCEPT"]]
	for language: String in options:
		var button := options[language] as Button
		button.focus_entered.connect(TranslationServer.set_locale.bind(language))
		button.mouse_entered.connect(button.grab_focus)
		button.pressed.connect(_choose.bind(language))


func focus_default() -> void:
	(options[Settings.language()] as Button).grab_focus()


func _choose(language: String) -> void:
	Settings.set_value(&"language", language)
	chosen.emit(language)
	MenuStack.pop()
