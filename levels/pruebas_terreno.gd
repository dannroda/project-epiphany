extends Node3D
## Prueba 12.14: la misma zona con cada estilo de borde, una al lado de la otra. 1–7 llevan al player al mismo lugar
## de cada una.

const SPAWN := Vector3(-7.0, 0.5, 1.0)

@onready var _variants: Node3D = $Variantes
@onready var _label: Label = %Nombre
@onready var _player: Node3D = $Player


func _ready() -> void:
	_go(0)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode < KEY_1 + _variants.get_child_count():
		_go(key.keycode - KEY_1)


func _go(index: int) -> void:
	var variant := _variants.get_child(index) as Node3D
	_player.global_position = variant.global_position + SPAWN
	_label.text = "%d · %s   (1–%d cambia)" % [index + 1, variant.name, _variants.get_child_count()]
