extends UiScreen
## Mini tutorial de un ítem (11.105, mockup Tutorial_Card): después del item get, qué hace, con qué botón y dónde
## probarlo enseguida. Pausa hasta confirmar.

signal closed

const GOLD := Color("#d9a441")

var tutorial: TutorialData
## Cuánto tarda en aceptar el botón, para que el que cerró el item get no la cierre también.
@export var input_guard := 0.3

@onready var badge: Control = %Badge
@onready var icon: TextureRect = %Icon
@onready var title: Label = %Title
@onready var what: RichTextLabel = %What
@onready var button: RichTextLabel = %Button
@onready var try: RichTextLabel = %Try
@onready var hints: HintBar = %Hints

var _guard := 0.0


func _ready() -> void:
	icon.texture = tutorial.item.icon
	title.text = tr(tutorial.item.display_name)
	for pair: Array in [[what, tutorial.what], [button, tutorial.button], [try, tutorial.try]]:
		TextBox.fill_rich(pair[0], tr(pair[1]), 30)
	hints.hints = [[&"ui_accept", tr("TUT_OK")]]
	badge.draw.connect(_draw_badge)
	_guard = input_guard
	tree_exiting.connect(closed.emit)


func _process(delta: float) -> void:
	_guard -= delta


func _unhandled_input(event: InputEvent) -> void:
	if _guard <= 0.0 and (event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"attack")):
		get_viewport().set_input_as_handled()
		MenuStack.pop()


func _draw_badge() -> void:
	var center := badge.size / 2.0
	badge.draw_circle(center, center.x, Color(GOLD, 0.1))
	badge.draw_arc(center, center.x - 0.5, 0.0, TAU, 64, Color(GOLD, 0.8), 1.0, true)
