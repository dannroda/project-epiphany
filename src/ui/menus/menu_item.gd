class_name MenuItem
extends Button
## Opción de un menú vertical (título, game over, diálogos): con foco, dorada y con "▶". El estilo es la variación
## MenuItem del tema.

@export var label := "":
	set(value):
		label = value
		_refresh()


func _ready() -> void:
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	mouse_entered.connect(func() -> void:
		if not disabled:
			grab_focus())
	_refresh()


func _refresh() -> void:
	if is_node_ready():
		text = ("▶  " + label) if has_focus() else label
