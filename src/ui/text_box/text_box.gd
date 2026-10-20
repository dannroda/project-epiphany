class_name TextBox
extends UiScreen
## Globo de Dialogue Manager con los estilos de los mockups: cada línea es una página, letra por letra.
## Avanza con interact/attack/aceptar; el mismo botón completa la línea. Si la línea trae respuestas, al terminar de
## escribirse aparecen en la caja (estilo ITEM) y elegir una sigue por su `next_id`.

signal finished

const SCENE := preload("res://src/ui/text_box/text_box.tscn")
const RESPONSE := preload("res://src/ui/text_box/response_button.tscn")
const ADVANCE: Array[StringName] = [&"interact", &"attack", &"ui_accept"]
## También se consumen para que no cierren la pila ni abran la pausa.
const SWALLOW: Array[StringName] = [&"ui_cancel", &"pause"]

enum Style { ITEM, STONE }

## `{btn:accion}` en el texto se muestra como el ícono del botón de esa acción en el dispositivo actual;
## `{btn:move}`, el stick o las cuatro teclas; `{item:id}`, el botón al que está asignado ese ítem.
const BUTTON_TOKEN := "\\{(btn|item):(\\w+)\\}"
const MOVE_ACTIONS: Array[StringName] = [&"move_forward", &"move_left", &"move_backward", &"move_right"]
const BUTTON_ICON_SIZE := 32

@export var chars_per_second := 45.0
## Tras abrir o cambiar de línea se ignora el input un instante: apretar rápido no saltea líneas.
@export var input_guard := 0.25

@onready var dim: ColorRect = %Dim
@onready var item_box: PanelContainer = %ItemBox
@onready var stone_box: PanelContainer = %StoneBox
@onready var hint: HBoxContainer = %Hint
@onready var hint_icon: TextureRect = %HintIcon
@onready var responses_rule: ColorRect = %ResponsesRule
@onready var responses: VBoxContainer = %Responses
@onready var response_hints: HBoxContainer = %ResponseHints

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
## El texto de la línea: el Label, o el RichTextLabel si la línea trae íconos de botón.
var body: Variant
var _label: Label
var _rich: RichTextLabel

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
	box.finished.connect(MenuStack.close.bind(box))
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
	_label = box.find_child("Body") as Label
	_rich = box.find_child("RichBody") as RichTextLabel
	_rich.add_theme_font_override(&"normal_font", _label.get_theme_font(&"font"))
	_rich.add_theme_font_size_override(&"normal_font_size", _label.get_theme_font_size(&"font_size"))
	_rich.add_theme_color_override(&"default_color", _label.get_theme_color(&"font_color"))
	body = _label
	_next = box.find_child("Next", true, false) as Node2D
	response_hints.hints = [[&"ui_accept", "HINT_CHOOSE"]]
	hint_icon.texture = InputPrompts.icon_for_current(&"ui_accept" if InputDevice.current == InputDevice.Device.GAMEPAD else &"interact")
	_label.text = ""
	_fetch(cue)


func _process(delta: float) -> void:
	_guard = maxf(_guard - delta, 0.0)
	if not is_page_done():
		_shown += chars_per_second * delta
		body.visible_characters = int(_shown)
	elif _has_responses() and not responses.visible:
		_show_responses()
	if _next:
		_next.visible = is_page_done() and not _waiting and not responses.visible


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
	if responses.visible:
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused and focused.get_parent() == responses:
			focused.pressed.emit()
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
	_hide_responses()
	page += 1
	var heading := title_override if not title_override.is_empty() else tr(character, &"character")
	title_label.text = heading
	title_label.visible = not heading.is_empty()
	_set_body(text)
	_shown = 0.0
	body.visible_characters = 0
	_guard = input_guard


func _set_body(text: String) -> void:
	var tokens := RegEx.create_from_string(BUTTON_TOKEN)
	var rich := tokens.search(text) != null
	_label.visible = not rich
	_rich.visible = rich
	body = _rich if rich else _label
	if not rich:
		_label.text = text
		return
	_rich.clear()
	var from := 0
	for found in tokens.search_all(text):
		_rich.add_text(text.substr(from, found.get_start() - from))
		for action in _token_actions(found.get_string(1), found.get_string(2)):
			var icon := InputPrompts.icon_for_current(action)
			if icon:
				_rich.add_image(icon, BUTTON_ICON_SIZE, BUTTON_ICON_SIZE, Color.WHITE, INLINE_ALIGNMENT_CENTER)
			else:
				_rich.add_text(action)
		from = found.get_end()
	_rich.add_text(text.substr(from))


func _token_actions(kind: String, value: String) -> Array[StringName]:
	if kind == "item":
		var button := GameState.item_buttons.find(StringName(value))
		return [PlayerCharacter.ITEM_ACTIONS[maxi(button, 0)]]
	if value == "move":
		return MOVE_ACTIONS.slice(0, 1) if InputDevice.current == InputDevice.Device.GAMEPAD else MOVE_ACTIONS
	return [StringName(value)]


func _has_responses() -> bool:
	return style == Style.ITEM and line != null and not line.responses.is_empty()


func _show_responses() -> void:
	for response: DialogueResponse in line.responses:
		if not response.is_allowed:
			continue
		var button: Button = RESPONSE.instantiate()
		button.text = response.text
		button.pressed.connect(_choose.bind(response))
		responses.add_child(button)
	responses_rule.visible = true
	responses.visible = true
	response_hints.visible = true
	if responses.get_child_count() > 0:
		(responses.get_child(0) as Button).grab_focus()
	_guard = input_guard


func _hide_responses() -> void:
	responses_rule.visible = false
	responses.visible = false
	response_hints.visible = false
	for child in responses.get_children():
		responses.remove_child(child)
		child.queue_free()


func _choose(response: DialogueResponse) -> void:
	if _waiting or _guard > 0.0:
		return
	_hide_responses()
	_fetch(response.next_id)


func _end() -> void:
	set_process_unhandled_input(false)
	finished.emit()
