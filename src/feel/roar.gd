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
	add_child(ring)
	var forward := -global_basis.z.normalized()
	ring.global_transform = Transform3D(Basis.looking_at(forward) * Basis(Vector3.RIGHT, -PI / 2.0), global_position)
	ring.scale = Vector3.ONE * size * 0.15
	ring.set_instance_shader_parameter(&"outer", color)
	ring.set_instance_shader_parameter(&"inner", inner)
	ring.set_instance_shader_parameter(&"seed", randf() * 100.0)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, ^"scale", Vector3.ONE * size, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, ^"global_position", global_position + forward * reach, 0.6)
	tween.tween_method(func(value: float) -> void: ring.set_instance_shader_parameter(&"fade", value), 1.0, 0.0, 0.6).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring.queue_free)
