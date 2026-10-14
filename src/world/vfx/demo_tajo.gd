@tool
extends Node3D
## Prueba del tajo de espada (tajo.gdshader): una hoja barre en loop y la media luna la sigue desde donde arrancó hasta
## la punta, después se apaga. Corre también en el editor.

@export var swing_time := 0.16
@export_range(0.0, 6.0) var swing_angle := 2.6
@export var fade_time := 0.22
@export var pause := 0.8

var _time := 0.0

@onready var blade: Node3D = $Hoja
@onready var tip: Marker3D = $Hoja/Punta
@onready var slash: MeshInstance3D = $Tajo
@onready var sparks: GPUParticles3D = $Tajo/Chispas


func _process(delta: float) -> void:
	_time = fmod(_time + delta, swing_time + fade_time + pause)
	var from := swing_angle * 0.5
	var angle := lerpf(from, -from, ease(clampf(_time / swing_time, 0.0, 1.0), 0.6))
	blade.rotation.y = angle
	slash.set_instance_shader_parameter(&"start", from)
	slash.set_instance_shader_parameter(&"head", angle)
	slash.set_instance_shader_parameter(&"fade", clampf((_time - swing_time) / fade_time, 0.0, 1.0))
	sparks.global_position = tip.global_position
	sparks.emitting = _time < swing_time
