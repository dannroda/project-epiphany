class_name Roar
extends Node3D
## El grito de presentación de un jefe: sonido, temblor y ondas que salen hacia adelante (-Z) desde acá, con los colores
## de su mazmorra (`color` afuera, `inner` adentro). Anda durante la pausa del acercamiento de la cámara (process_mode siempre).

const RING := preload("res://src/feel/roar_ring.tscn")

@export var duration := 1.0
@export var rings := 4
@export var color := Color(0.75, 1.0, 0.95, 0.55)
@export var inner := Color(1.0, 1.0, 1.0)
@export var size := 1.9
@export var reach := 1.6
@export var shake := 0.5


func play() -> void:
	Feel.sfx(&"roar", global_position, true)
	Feel.shake(shake)
	for i in rings:
		get_tree().create_timer(0.12 + i * duration / rings, true).timeout.connect(_ring)


func _ring() -> void:
	if not is_inside_tree():
		return
	var ring := RING.instantiate() as MeshInstance3D
	ring.top_level = true
	ring.size = size
	ring.reach = reach
	add_child(ring)
	ring.forward = -global_basis.z.normalized()
	ring.origin = global_position
	ring.global_transform = Transform3D(Basis.looking_at(ring.forward) * Basis(Vector3.RIGHT, -PI / 2.0), global_position)
	ring.grow = 0.0
	ring.set_instance_shader_parameter(&"outer", color)
	ring.set_instance_shader_parameter(&"inner", inner)
	ring.set_instance_shader_parameter(&"seed", randf() * 100.0)
	ring.spread()
