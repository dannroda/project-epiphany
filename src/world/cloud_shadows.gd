extends Node
## Prende las sombras de nubes de los materiales de afuera (data/kits/shaders/cloud_shadows.gdshaderinc) mientras
## está en el árbol.

@export_range(0.0, 1.0) var strength := 0.32
## Tamaño de las nubes en metros.
@export var size := 13.0
## Hacia dónde y a cuántos m/s van.
@export var drift := Vector2(1.1, 0.45)


func _enter_tree() -> void:
	RenderingServer.global_shader_parameter_set(&"cloud_shadows", value())


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set(&"cloud_shadows", Vector4.ZERO)


func value() -> Vector4:
	return Vector4(strength, size, drift.x, drift.y)
