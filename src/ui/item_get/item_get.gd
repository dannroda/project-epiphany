extends Control
## Item get: el ícono en anillos sobre el player y una caja con el nombre y la descripción. Pausa hasta confirmar.

signal closed

const GOLD := Color("#d9a441")
const ICON_SIZE := 80.0
## Evita que el mismo botón que abrió el cofre cierre la caja.
const ACCEPT_DELAY := 0.35

var item: ItemData
var amount := 1
## Centro de los anillos, en pantalla.
var anchor := Vector2(640, 215)

@onready var rings: Control = %Rings
@onready var icon: TextureRect = %Icon
@onready var title: Label = %Title
@onready var text: Label = %Text

var _opened_at := 0


func _ready() -> void:
	_opened_at = Time.get_ticks_msec()
	icon.texture = item.icon
	title.text = title_for(item, amount)
	text.text = item.description
	rings.position = anchor - rings.size / 2.0
	rings.draw.connect(_draw_rings)
	tree_exiting.connect(closed.emit)
	var box := $Box as Control
	box.resized.connect(func() -> void: $Box/Next.position = box.size - Vector2(44, 32))


static func title_for(given: ItemData, count: int) -> String:
	if count > 1:
		return "¡Conseguiste %d %s!" % [count, given.display_name]
	if given.article.is_empty():
		return "¡Conseguiste %s!" % given.display_name
	return "¡Conseguiste %s %s!" % [given.article, given.display_name]


func _unhandled_input(event: InputEvent) -> void:
	if Time.get_ticks_msec() - _opened_at < ACCEPT_DELAY * 1000.0:
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"interact") or event.is_action_pressed(&"attack"):
		get_viewport().set_input_as_handled()
		MenuStack.pop()


func _draw_rings() -> void:
	var center := rings.size / 2.0
	rings.draw_circle(center, 58.0, Color(GOLD, 0.1))
	rings.draw_arc(center, 75.0, 0.0, TAU, 96, Color(GOLD, 0.55), 2.0, true)
	rings.draw_arc(center, 58.0, 0.0, TAU, 96, Color(GOLD, 0.8), 1.0, true)
