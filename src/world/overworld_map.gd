class_name OverworldMap
extends Node
## Va en las escenas del overworld: el mapa simple de la zona (imagen fija) y qué rectángulo del mundo (XZ) cubre.

@export var display_name: String = ""
@export var texture: Texture2D
@export var world_rect := Rect2(-20, -20, 40, 40)
