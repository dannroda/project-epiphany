class_name MapDungeonItem
extends PanelContainer
## Un ítem de la mazmorra en la pestaña Mapa: ícono y nombre, apagado si no se tiene.

@export var item_id: StringName
@export var label := ""

@onready var icon: TextureRect = %Icon
@onready var count: Label = %Count


func _ready() -> void:
	var item := Items.get_item(item_id)
	icon.texture = item.icon if item else null
	(%Name as Label).text = label


func show_owned(owned: bool, amount := -1) -> void:
	modulate = Color.WHITE if owned else Color(1, 1, 1, 0.4)
	count.visible = amount >= 0
	count.text = str(amount)
