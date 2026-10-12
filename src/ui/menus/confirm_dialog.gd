class_name ConfirmDialog
extends UiScreen
## Confirmación sobre la pantalla actual: la opción segura (Cancelar) arranca con el foco; atrás también cancela.

signal answered(confirmed: bool)

const SCENE_PATH := "res://src/ui/menus/confirm_dialog.tscn"

## Arranca con el foco en confirmar (el viaje rápido: elegir el portal ya fue la decisión).
@export var confirm_first := false

@onready var question: Label = %Question
@onready var yes: Button = %Yes
@onready var no: Button = %No

var _question := ""
var _confirm := ""


## `scene`: una variante de confirm_dialog.tscn (el viaje rápido suma ícono y detalle).
static func ask(text: String, confirm_label: String, scene := SCENE_PATH) -> ConfirmDialog:
	var dialog: ConfirmDialog = load(scene).instantiate()
	dialog._question = text
	dialog._confirm = confirm_label
	MenuStack.push(dialog)
	return dialog


func _ready() -> void:
	question.text = _question
	yes.text = _confirm
	yes.pressed.connect(_answer.bind(true))
	no.pressed.connect(_answer.bind(false))


func focus_default() -> void:
	(yes if confirm_first else no).grab_focus()


func cancel() -> bool:
	_answer(false)
	return true


func _answer(confirmed: bool) -> void:
	MenuStack.pop()
	answered.emit(confirmed)
