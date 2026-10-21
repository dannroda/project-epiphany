class_name BenchMarker
extends Node
## Un extremo de los callbacks del cuadro (15.20): con la prioridad más baja corre antes que todos y con la más alta,
## después. El del final suma lo que tardaron los scripts entre los dos (en process y en cada paso de física) y, entre
## dos pasos del mismo cuadro, lo que tardó el motor del fin de unos scripts al principio de los siguientes (navegación,
## llamadas diferidas, el paso de Jolt y sus señales).

## En el del principio: el del final. En el del final: el del principio.
@export var start: BenchMarker
@export var end: BenchMarker

var process_at := 0
var physics_at := 0
var physics_frame := -1
## Desde el último take(): µs de scripts en process, µs de scripts en física, pasos, µs de motor entre pasos y huecos.
var process_us := 0
var physics_us := 0
var steps := 0
var engine_us := 0
var gaps := 0


func _process(_delta: float) -> void:
	process_at = Time.get_ticks_usec()
	if start:
		process_us += process_at - start.process_at


func _physics_process(_delta: float) -> void:
	physics_at = Time.get_ticks_usec()
	if start:
		physics_us += physics_at - start.physics_at
		steps += 1
		physics_frame = Engine.get_process_frames()
	elif end and end.physics_frame == Engine.get_process_frames():
		end.engine_us += physics_at - end.physics_at
		end.gaps += 1


## [ms de scripts en process, ms de scripts en física, pasos, ms de motor entre pasos, huecos] desde la última vez.
func take() -> Array:
	var taken := [process_us / 1000.0, physics_us / 1000.0, steps, engine_us / 1000.0, gaps]
	process_us = 0
	physics_us = 0
	steps = 0
	engine_us = 0
	gaps = 0
	return taken
