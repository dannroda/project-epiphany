class_name HeartPiece
extends Pickup
## Pieza de corazón escondida en el mundo: se levanta con item get y no vuelve una vez tomada. La tomada queda
## oculta (no se borra) así el mapa puede contar cuántas hay por zona.

@export var flag: StringName

var taken := false


func _ready() -> void:
	super()
	_vertical_speed = 0.0
	GameState.loaded.connect(_sync)
	_sync()


## Al cargar una partida sin cambiar de escena, la pieza aparece o desaparece según esa partida.
func _sync() -> void:
	if GameState.get_flag(flag) == true:
		_consume()
	elif taken:
		taken = false
		visible = true
		set_physics_process(true)
		set_deferred(&"monitoring", true)


func collect(player: PlayerCharacter) -> void:
	GameState.set_flag(flag, true)
	super(player)


func _consume() -> void:
	taken = true
	visible = false
	set_physics_process(false)
	set_deferred(&"monitoring", false)
