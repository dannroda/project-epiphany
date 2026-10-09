extends OmniLight3D
## Luz de antorcha: titila con un ruido suave alrededor de su energía base.

@export var amount := 0.25
@export var speed := 7.0

var _base := 1.0
var _time := randf() * 100.0


func _ready() -> void:
	_base = light_energy


func _process(delta: float) -> void:
	_time += delta * speed
	light_energy = _base * (1.0 + amount * (sin(_time) * 0.6 + sin(_time * 2.3 + 1.7) * 0.4))
