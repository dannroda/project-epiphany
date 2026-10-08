extends Control
## Item get: el ícono en anillos sobre el player y la caja de texto con el nombre y la descripción. Pausa hasta confirmar.

signal closed

const GOLD := Color("#d9a441")

var item: ItemData
var amount := 1
## Centro de los anillos, en pantalla.
var anchor := Vector2(640, 215)
var text_box: TextBox

@onready var rings: Control = %Rings
@onready var icon: TextureRect = %Icon


func _ready() -> void:
	icon.texture = item.icon
	rings.position = anchor - rings.size / 2.0
	rings.draw.connect(_draw_rings)
	text_box = TextBox.SCENE.instantiate()
	text_box.data = TextData.make([item.description], title_for(item, amount), TextData.Style.ITEM)
	text_box.finished.connect(MenuStack.pop)
	add_child(text_box)
	move_child(text_box, 0)
	tree_exiting.connect(closed.emit)


static func title_for(given: ItemData, count: int) -> String:
	var item_name := given.tr(given.display_name)
	if count > 1:
		return "¡Conseguiste %d %s!" % [count, item_name]
	if given.article.is_empty():
		return "¡Conseguiste %s!" % item_name
	return "¡Conseguiste %s %s!" % [given.article, item_name]


func _draw_rings() -> void:
	var center := rings.size / 2.0
	rings.draw_circle(center, 58.0, Color(GOLD, 0.1))
	rings.draw_arc(center, 75.0, 0.0, TAU, 96, Color(GOLD, 0.55), 2.0, true)
	rings.draw_arc(center, 58.0, 0.0, TAU, 96, Color(GOLD, 0.8), 1.0, true)
