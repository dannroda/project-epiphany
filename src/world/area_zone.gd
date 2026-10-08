class_name AreaZone
extends Area3D
## Zona del overworld: al entrar el player, el HUD muestra su nombre (solo si viene de otra zona).

static var _current: AreaZone

@export var display_name: String = ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerCharacter and _current != self:
			_current = self
			if not display_name.is_empty():
				get_tree().call_group(&"hud", &"show_area_name", tr(display_name)))


func _exit_tree() -> void:
	if _current == self:
		_current = null
