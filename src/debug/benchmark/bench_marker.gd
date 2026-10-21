class_name BenchMarker
extends Node
## Un extremo de los callbacks del cuadro (15.20): con la prioridad más baja corre antes que todos y con la más alta,
## después. El del final suma lo que tardaron los scripts entre los dos (en process y en cada paso de física).

## El marcador del principio; vacío en el del principio mismo.
@export var start: BenchMarker

var process_at := 0
var physics_at := 0
## Desde el último take(): µs de scripts en process, µs de scripts en física y pasos de física.
var process_us := 0
var physics_us := 0
var steps := 0


func _process(_delta: float) -> void:
	process_at = Time.get_ticks_usec()
	if start:
		process_us += process_at - start.process_at


func _physics_process(_delta: float) -> void:
	physics_at = Time.get_ticks_usec()
	if start:
		physics_us += physics_at - start.physics_at
		steps += 1


## [ms de scripts en process, ms de scripts en física, pasos] desde la última vez.
func take() -> Array:
	var taken := [process_us / 1000.0, physics_us / 1000.0, steps]
	process_us = 0
	physics_us = 0
	steps = 0
	return taken
