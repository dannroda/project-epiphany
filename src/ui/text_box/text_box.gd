class_name TextBox
extends Control
## Globo de Dialogue Manager con los estilos de los mockups: cada línea es una página, letra por letra.
## Avanza con interact/attack/aceptar; el mismo botón completa la línea.

signal finished

const SCENE := preload("res://src/ui/text_box/text_box.tscn")
const ADVANCE: Array[StringName] = [&"interact", &"attack", &"ui_accept"]
## También se consumen para que no cierren la pila ni abran la pausa.
const SWALLOW: Array[StringName] = [&"ui_cancel", &"pause"]

enum Style { ITEM, STONE }

@export var chars_per_second := 45.0
## Tras abrir o cambiar de línea se ignora el input un instante: apretar rápido no saltea líneas.
@export var input_guard := 0.25

@onready var dim: ColorRect = %Dim
@onready var item_box: PanelContainer = %ItemBox
@onready var stone_box: PanelContainer = %StoneBox
@onready var hint: HBoxContainer = %Hint
@onready var hint_icon: TextureRect = %HintIcon

var style := Style.STONE
var resource: DialogueResource
var cue := ""
var extra_states: Array = []
## Sin recurso: líneas fijas (la descripción de un ítem en item get).
var lines: PackedStringArray = []
## Reemplaza el nombre del personaje como título (item get).
var title_override := ""
var line: DialogueLine
## Cuántas líneas se mostraron (0 = la primera).
var page := -1
var title_label: Label
var body: Label

var _next: Node2D
var _shown := 0.0
var _guard := 0.0
var _waiting := false


## Abre un globo solo en la pila de menús (pausa el juego).
static func open(dialogue: DialogueResource, start_cue := "", box_style := Style.STONE, states: Array = []) -> TextBox:
	var box: TextBox = SCENE.instantiate()
	box.resource = dialogue
	box.cue = start_cue
	box.style = box_style
	box.extra_states = states
	box.finished.connect(MenuStack.pop)
	MenuStack.push(box)
	return box


func _ready() -> void:
	DialogueManager.process_mode = Node.PROCESS_MODE_ALWAYS
	var stone := style == Style.STONE
	stone_box.visible = stone
	item_box.visible = not stone
	hint.visible = stone
	dim.color.a = 0.4 if stone else 0.45
	var box := stone_box if stone else item_box
	title_label = box.find_child("Title") as Label
	body = box.find_child("Body") as Label
	_next = box.find_child("Next", true, false) as Node2D
	if _next:
		_next.set_meta(&"base_y", _next.position.y)
	hint_icon.texture = InputPrompts.icon_for_current(&"ui_accept" if InputDevice.current == InputDevice.Device.GAMEPAD else &"interact")
	body.text = ""
	_fetch(cue)


func _process(delta: float) -> void:
	_guard = maxf(_guard - delta, 0.0)
	if not is_page_done():
		_shown += chars_per_second * delta
		body.visible_characters = int(_shown)
	if _next:
		_next.visible = is_page_done() and not _waiting
		_next.position.y = _next.get_meta(&"base_y") + 3.0 * sin(Time.get_ticks_msec() / 150.0)


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


## Completa la línea, pasa a la siguiente o termina.
func advance() -> void:
	if _waiting:
		return
	if not is_page_done():
		body.visible_characters = -1
		_guard = input_guard
	elif resource:
		_fetch(line.next_id)
	else:
		_show_text(page + 1, "")


func _fetch(key: String) -> void:
	if resource == null:
		_show_text(0, "")
		return
	_waiting = true
	var next: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, key, extra_states)
	_waiting = false
	if not is_inside_tree():
		return
	if next == null:
		_end()
		return
	line = next
	_show(line.text, line.character)


func _show_text(index: int, character: String) -> void:
	if index >= lines.size():
		_end()
		return
	_show(tr(lines[index]), character)


func _show(text: String, character: String) -> void:
	page += 1
	var heading := title_override if not title_override.is_empty() else character
	title_label.text = heading
	title_label.visible = not heading.is_empty()
	body.text = text
	_shown = 0.0
	body.visible_characters = 0
	_guard = input_guard


func _end() -> void:
	set_process_unhandled_input(false)
	finished.emit()
