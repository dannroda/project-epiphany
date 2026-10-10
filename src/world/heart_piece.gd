class_name HeartPiece
extends Pickup
## Pieza de corazón escondida en el mundo: se levanta con item get y no vuelve una vez tomada. La tomada queda
## oculta (no se borra) así el mapa puede contar cuántas hay por zona.

@export var flag: StringName

var taken := false


func _ready() -> void:
	super()
	_vertical_speed = 0.0
	if GameState.get_flag(flag) == true:
		_consume()


func collect(player: PlayerCharacter) -> void:
	GameState.set_flag(flag, true)
	super(player)


func _consume() -> void:
	taken = true
	visible = false
	set_physics_process(false)
	set_deferred(&"monitoring", false)
