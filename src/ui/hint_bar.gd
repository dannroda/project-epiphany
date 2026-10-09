class_name HintBar
extends HBoxContainer
## Fila de pistas de botones ("[A] Aceptar  [B] Volver") con los íconos del dispositivo actual. Cada pista es una
## instancia de hint_item.tscn.

const ITEM := preload("res://src/ui/hint_item.tscn")

## Pares [acción, texto]; texto vacío = solo el ícono. La acción puede ser un par de acciones ([Q][E] Pestaña).
var hints: Array = []:
	set(value):
		hints = value
		if is_node_ready():
			_refresh()


func _ready() -> void:
	InputDevice.input_device_changed.connect(func(_device: int) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for hint in hints:
		var item := ITEM.instantiate()
		var actions: Array = hint[0] if hint[0] is Array else [hint[0]]
		(item.get_node(^"Icon") as TextureRect).texture = InputPrompts.icon_for_current(actions[0])
		var second := item.get_node(^"Icon2") as TextureRect
		second.visible = actions.size() > 1
		if second.visible:
			second.texture = InputPrompts.icon_for_current(actions[1])
		var label := item.get_node(^"Label") as Label
		label.text = hint[1]
		label.visible = not String(hint[1]).is_empty()
		add_child(item)
