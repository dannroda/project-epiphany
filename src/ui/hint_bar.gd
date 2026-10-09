class_name HintBar
extends HBoxContainer
## Fila de pistas de botones ("[A] Aceptar  [B] Volver") con los íconos del dispositivo actual.

## Pares [acción, texto]; texto vacío = solo el ícono.
var hints: Array = []:
	set(value):
		hints = value
		if is_node_ready():
			_refresh()


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	InputDevice.input_device_changed.connect(func(_device: int) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for hint in hints:
		var icon := TextureRect.new()
		icon.texture = InputPrompts.icon_for_current(hint[0])
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(icon)
		if not String(hint[1]).is_empty():
			var label := Label.new()
			label.text = hint[1] + "    "
			label.theme_type_variation = &"Hint"
			add_child(label)
