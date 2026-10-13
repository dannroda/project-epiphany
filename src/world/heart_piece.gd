class_name HeartPiece
extends Pickup
## Pieza de corazón escondida en el mundo: se levanta con item get y no vuelve una vez tomada. La tomada queda
## oculta (no se borra) así el mapa puede contar cuántas hay por zona.

@export var flag: StringName
## No está a la vista hasta que algo la suelta con reveal() (la queñoa que se sacude), en cada visita.
@export var hidden_until_revealed := false

var taken := false
var _revealed := false


func _ready() -> void:
	super()
	_vertical_speed = 0.0
	GameState.loaded.connect(_sync)
	_sync()


## Al cargar una partida sin cambiar de escena, la pieza aparece o desaparece según esa partida.
func _sync() -> void:
	if GameState.get_flag(flag) == true:
		_consume()
		return
	taken = false
	var shown := _revealed or not hidden_until_revealed
	visible = shown
	set_physics_process(shown)
	set_deferred(&"monitoring", shown)


func reveal() -> void:
	if taken or _revealed:
		return
	_revealed = true
	_age = 0.0
	_vertical_speed = 6.0
	_sync()


func collect(player: PlayerCharacter) -> void:
	GameState.set_flag(flag, true)
	super(player)


func _consume() -> void:
	taken = true
	visible = false
	set_physics_process(false)
	set_deferred(&"monitoring", false)
