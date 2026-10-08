class_name TextBox
extends Control
## Caja de texto: letra por letra, varias páginas. Avanza con interact/attack/aceptar; el mismo botón completa la página.

signal finished

const SCENE := preload("res://src/ui/text_box/text_box.tscn")
const ADVANCE: Array[StringName] = [&"interact", &"attack", &"ui_accept"]
## También se consumen para que no cierren la pila ni abran la pausa.
const SWALLOW: Array[StringName] = [&"ui_cancel", &"pause"]

@export var chars_per_second := 45.0
## Tras abrir o cambiar de página se ignora el input un instante: apretar rápido no saltea páginas.
@export var input_guard := 0.25

@onready var dim: ColorRect = %Dim
@onready var item_box: PanelContainer = %ItemBox
@onready var stone_box: PanelContainer = %StoneBox
@onready var hint: HBoxContainer = %Hint
@onready var hint_icon: TextureRect = %HintIcon

var data: TextData
var page := 0
var title_label: Label
var body: Label
var _next: Node2D
var _shown := 0.0
var _guard := 0.0


## Abre una caja sola en la pila de menús (pausa el juego).
static func open(text: TextData) -> TextBox:
	var box: TextBox = SCENE.instantiate()
	box.data = text
	box.finished.connect(MenuStack.pop)
	MenuStack.push(box)
	return box


func _ready() -> void:
	var stone := data.style == TextData.Style.STONE
	stone_box.visible = stone
	item_box.visible = not stone
	hint.visible = stone
	dim.color.a = 0.4 if stone else 0.45
	var box := stone_box if stone else item_box
	title_label = box.find_child("Title") as Label
	body = box.find_child("Body") as Label
	_next = box.find_child("Next", true, false) as Node2D
	title_label.text = tr(data.title)
	title_label.visible = not data.title.is_empty()
	hint_icon.texture = InputPrompts.icon_for_current(&"ui_accept" if InputDevice.current == InputDevice.Device.GAMEPAD else &"interact")
	_show_page(0)


func _process(delta: float) -> void:
	_guard = maxf(_guard - delta, 0.0)
	if not is_page_done():
		_shown += chars_per_second * delta
		body.visible_characters = int(_shown)
	if _next:
		_next.visible = is_page_done()
		_next.position.y = _next.get_meta(&"base_y", _next.position.y) + 3.0 * sin(Time.get_ticks_msec() / 150.0)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	for action in ADVANCE + SWALLOW:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			if _guard <= 0.0:
				advance()
			return


func is_page_done() -> bool:
	return body.visible_characters < 0 or body.visible_characters >= body.get_total_character_count()


## Completa la página, pasa a la siguiente o termina.
func advance() -> void:
	if not is_page_done():
		body.visible_characters = -1
		_guard = input_guard
	elif page + 1 < data.pages.size():
		_show_page(page + 1)
	else:
		set_process_unhandled_input(false)
		finished.emit()


func _show_page(index: int) -> void:
	page = index
	body.text = tr(data.pages[index]) if index < data.pages.size() else ""
	_shown = 0.0
	body.visible_characters = 0
	_guard = input_guard
	if _next and not _next.has_meta(&"base_y"):
		_next.set_meta(&"base_y", _next.position.y)
