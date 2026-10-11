class_name ControlRow
extends HBoxContainer
## Una fila de la pantalla de controles (mockups Controls_Gamepad y Controls_Keyboard): lo que hace y los íconos de
## sus acciones en el dispositivo de la vista, leídos del InputMap.

@export var actions: Array[StringName] = []
@export var gamepad := true
## Para lo que no es una acción (mirar con el mouse, la cruceta libre).
@export var fixed_icon: Texture2D

@onready var icons: HBoxContainer = $Icons


func _ready() -> void:
	refresh()


func refresh() -> void:
	var textures: Array[Texture2D] = []
	if fixed_icon:
		textures.append(fixed_icon)
	for action in actions:
		for texture in InputPrompts.icons(action, gamepad):
			if not textures.has(texture):
				textures.append(texture)
	for i in icons.get_child_count():
		var rect := icons.get_child(i) as TextureRect
		rect.visible = i < textures.size()
		rect.texture = textures[i] if rect.visible else null
