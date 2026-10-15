class_name Teleport
extends Node3D
## El teletransporte de los portales, como en Mega Man: al irse, el player queda en silueta, se vuelve una esfera de luz
## que se cierra en un rayo y sale disparado para arriba; al llegar, el rayo cae, revienta en la esfera y se abre en el
## player, del color de la túnica puesta. Anda con el juego en pausa (el viaje la pide). Los que andan como espíritu
## (co-op) no se animan.

const SCENE := preload("res://src/feel/teleport.tscn")
## Lo que tardan (lo espera el viaje).
const DEPART_TIME := 0.7
const ARRIVE_TIME := 0.8

## Hasta dónde sube o desde dónde cae el rayo.
@export var sky := 14.0
## Alto del centro del cuerpo: ahí se arma la esfera.
@export var body_height := 0.95
## La esfera con la forma del cuerpo (ancho, alto, ancho) y abierta del todo.
@export var body_size := Vector3(0.9, 1.9, 0.9)
@export var burst_size := 1.7

var color := Color.WHITE

@onready var beam: MeshInstance3D = $Beam
@onready var bloom: MeshInstance3D = $Bloom
@onready var light: OmniLight3D = $Light


static func depart(player: PlayerCharacter) -> void:
	if not player.model.visible:
		return
	var fx := _spawn(player)
	await fx._depart(player)
	fx.queue_free()


static func arrive(player: PlayerCharacter) -> void:
	if player.spirit.visible:
		player.model.visible = false
		return
	var fx := _spawn(player)
	await fx._arrive(player)
	fx.queue_free()


static func _spawn(player: PlayerCharacter) -> Teleport:
	var fx := SCENE.instantiate() as Teleport
	player.get_parent().add_child(fx)
	fx.global_position = player.global_position
	fx.color = player.dodge_ghosts.tint()
	((fx.beam.mesh as PrimitiveMesh).material as ShaderMaterial).set_shader_parameter(&"color", fx.color)
	fx.light.light_color = fx.color
	return fx


func _depart(player: PlayerCharacter) -> void:
	var model := player.model
	var flash := player.get_node(^"%HitFlash") as HitFlash
	Feel.sfx(&"warp_out", global_position, true)
	var tween := create_tween().set_parallel()
	tween.tween_method(func(value: float) -> void: flash.hold(value, color), 0.0, 1.0, 0.18)
	await tween.finished
	model.visible = false
	flash.hold(0.0)
	bloom.position.y = body_height
	bloom.scale = body_size
	bloom.visible = true
	tween = create_tween()
	tween.tween_property(bloom, ^"scale", Vector3.ONE * burst_size, 0.1).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(light, ^"light_energy", 3.0, 0.1)
	tween.tween_property(bloom, ^"scale", Vector3(0.25, 3.0, 0.25), 0.14).set_ease(Tween.EASE_IN)
	await tween.finished
	bloom.visible = false
	beam.position.y = 1.5
	beam.visible = true
	tween = create_tween()
	tween.tween_property(beam, ^"position:y", sky, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(light, ^"light_energy", 0.0, 0.25)
	await tween.finished


func _arrive(player: PlayerCharacter) -> void:
	var model := player.model
	var flash := player.get_node(^"%HitFlash") as HitFlash
	model.visible = false
	beam.position.y = sky
	beam.visible = true
	var tween := create_tween()
	tween.tween_property(beam, ^"position:y", 1.5, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	Feel.sfx(&"warp_in", global_position, true)
	Feel.shake(0.15)
	beam.visible = false
	bloom.position.y = body_height
	bloom.scale = Vector3(0.25, 3.0, 0.25)
	bloom.visible = true
	tween = create_tween()
	tween.tween_property(bloom, ^"scale", Vector3.ONE * burst_size, 0.1).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(light, ^"light_energy", 3.0, 0.1)
	tween.tween_property(bloom, ^"scale", body_size, 0.14).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	bloom.visible = false
	model.visible = true
	flash.hold(1.0, color)
	tween = create_tween().set_parallel()
	tween.tween_method(func(value: float) -> void: flash.hold(value, color), 1.0, 0.0, 0.35)
	tween.tween_property(light, ^"light_energy", 0.0, 0.35)
	await tween.finished
