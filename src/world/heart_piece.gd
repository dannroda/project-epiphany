class_name HeartPiece
extends Pickup
## Pieza de corazón escondida en el mundo: se levanta con item get y no vuelve una vez tomada.

@export var flag: StringName


func _ready() -> void:
	if GameState.get_flag(flag) == true:
		queue_free()
		return
	super()
	_vertical_speed = 0.0


func collect(player: PlayerCharacter) -> void:
	GameState.set_flag(flag, true)
	super(player)
