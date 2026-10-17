class_name Teleport
extends Node3D
## El teletransporte de los portales, como en Mega Man: al irse, el player queda en silueta, se vuelve una esfera de luz
## que se cierra en un rayo y sale disparado para arriba; al llegar, el rayo cae, revienta en la esfera y se abre en el
## player, del color de la túnica puesta. Anda con el juego en pausa (el viaje la pide). Los que andan como espíritu
## (co-op) no se animan. Los clips "depart" y "arrive" de %Clip lo arman entero.

const SCENE := preload("res://src/feel/teleport.tscn")
## Lo que tardan (lo espera el viaje): el largo de cada clip.
const DEPART_TIME := 0.7
const ARRIVE_TIME := 0.8

var color := Color.WHITE
## Silueta del player en el color de la túnica (0..1).
var flash_amount := 0.0:
	set(value):
		flash_amount = value
		if _flash:
			_flash.hold(value, color)
var model_visible := true:
	set(value):
		model_visible = value
		if _model:
			_model.visible = value

var _flash: HitFlash
var _model: Node3D

@onready var beam: MeshInstance3D = $Beam
@onready var bloom: MeshInstance3D = $Bloom
@onready var light: OmniLight3D = $Light
@onready var clip: AnimationPlayer = %Clip


static func depart(player: PlayerCharacter) -> void:
	if not player.model.visible:
		return
	var fx := _spawn(player)
	await fx._play(&"depart")
	fx.queue_free()


static func arrive(player: PlayerCharacter) -> void:
	if player.spirit.visible:
		player.model.visible = false
		return
	var fx := _spawn(player)
	await fx._play(&"arrive")
	fx.queue_free()


static func _spawn(player: PlayerCharacter) -> Teleport:
	var fx := SCENE.instantiate() as Teleport
	player.get_parent().add_child(fx)
	fx.global_position = player.global_position
	fx.color = player.dodge_ghosts.tint()
	((fx.beam.mesh as PrimitiveMesh).material as ShaderMaterial).set_shader_parameter(&"color", fx.color)
	fx.light.light_color = fx.color
	fx._flash = player.get_node(^"%HitFlash") as HitFlash
	fx._model = player.model
	return fx


func _play(clip_name: StringName) -> void:
	clip.play(clip_name)
	await clip.animation_finished


func _cue_depart() -> void:
	Feel.sfx(&"warp_out", global_position, true)


func _cue_land() -> void:
	Feel.sfx(&"warp_in", global_position, true)
	Feel.shake(0.15)
