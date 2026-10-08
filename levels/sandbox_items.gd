extends Node3D
## Sala de pruebas de ítems: un puzzle por ítem. Cada uno abre un cubículo con una vasija de corazones.

@onready var cracked_wall: CrackedWall = $CrackedWall
@onready var gate_bow: Gate = $GateBow
@onready var gate_light: Gate = $GateLight
@onready var gate_orb: Gate = $GateOrb


func _ready() -> void:
	$EyeSwitch.activated.connect(gate_bow.open)
	$LightReceiver.activated.connect(gate_light.open)
	$Turret.health.died.connect(gate_orb.open)


## Cuántos de los cuatro puzzles están resueltos.
func solved() -> int:
	return [cracked_wall.is_broken, gate_bow.is_open, gate_light.is_open, gate_orb.is_open].count(true)
