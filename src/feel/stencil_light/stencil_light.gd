class_name StencilLight
extends Node3D
## Luz estilo Wind Waker: aclara lo que queda dentro de una esfera, con tres pasadas de stencil. Cada luz usa sus
## propias prioridades para que sus pasadas no se mezclen con las de otra; todas van antes que el destello y la
## silueta del player (prioridades 0 y 1), que usan la ref 1 del stencil.

const MATERIAL := preload("res://src/feel/stencil_light/stencil_light_material.tres")
const FIRST_PRIORITY := -127
const LAST_PRIORITY := -1

static var _next_priority := FIRST_PRIORITY

@export var color := Color(1.5, 1.25, 0.95)
@export var radius := 2.5:
	set(value):
		radius = value
		_resize()
@export var flicker := 0.05
@export var flicker_speed := 7.0
## Lo anima el clip "flicker" de $Flicker (dos senos, entre -1 y 1).
var pulse := 0.0:
	set(value):
		pulse = value
		_resize()

@onready var volume: MeshInstance3D = $Volume
@onready var _flicker: AnimationPlayer = $Flicker


func _ready() -> void:
	var material := MATERIAL.duplicate_deep() as ShaderMaterial
	var priority := _next_priority
	_next_priority = priority + 3 if priority + 5 <= LAST_PRIORITY else FIRST_PRIORITY
	material.render_priority = priority
	material.next_pass.render_priority = priority + 1
	material.next_pass.next_pass.render_priority = priority + 2
	(material.next_pass as ShaderMaterial).set_shader_parameter(&"color", color)
	volume.material_override = material
	_resize()
	if flicker > 0.0:
		_flicker.speed_scale = flicker_speed / 7.0
		_flicker.play(&"flicker")
		_flicker.seek(randf() * _flicker.current_animation_length, true)


func _resize() -> void:
	if volume:
		volume.scale = Vector3.ONE * radius * (1.0 + flicker * pulse)
