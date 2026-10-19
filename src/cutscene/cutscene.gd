class_name Cutscene
extends Node3D
## Cutscene (mockup Cutscene_Intro): su cámara y su AnimationPlayer mandan (planos, textos de `%Caption`, llamadas a
## `tremor` y `dust`); franjas arriba y abajo, sin HUD y los players quietos. Se saltea manteniendo aceptar
## (`skip_hold`). Al terminar, la cámara vuelve sola a la de juego.

signal finished

const SKIP_ACTIONS: Array[StringName] = [&"ui_accept", &"interact", &"attack"]

@export var animation := &"play"
@export var autoplay := true
## Lo que hay que mantener aceptar para saltearla.
@export var skip_hold := 0.8
## Lo que tarda la cámara en volver a la de juego, y las franjas en irse.
@export var settle_time := 1.2
@export var trauma_decay := 1.4
@export var max_shake := Vector2(0.4, 0.3)

@onready var camera: Camera3D = %Camera
@onready var player: AnimationPlayer = %AnimationPlayer
@onready var outro: AnimationPlayer = %Outro
@onready var caption: Label = %Caption
@onready var skip_ring: SkipRing = %SkipRing
@onready var skip_hint: Control = %SkipHint

var playing := false
var _held := 0.0
var _trauma := 0.0
var _shake_time := 0.0


func _ready() -> void:
	caption.text = ""
	skip_hint.visible = false
	(%SkipHints as HintBar).hints = [[&"ui_accept", "CUTSCENE_HOLD_SKIP"]]
	if autoplay:
		play.call_deferred()


func play() -> void:
	playing = true
	_set_gameplay(false)
	camera.make_current()
	skip_hint.visible = true
	player.play(animation)
	await player.animation_finished
	if playing:
		await _finish()


func skip() -> void:
	if not playing:
		return
	playing = false
	await SceneFlow.fade_out(0.3)
	player.stop()
	caption.text = ""
	_restore()
	await SceneFlow.fade_in(0.3)
	finished.emit()
	queue_free()


## Temblor (desde la animación): sacude esta cámara y hace vibrar el mando.
func tremor(amount: float) -> void:
	Feel.rumble(amount)
	if Feel.shakes():
		add_trauma(amount)
	Feel.sfx(&"rumble", camera.global_position)


## Polvo en un nodo de la cutscene (desde la animación).
func dust(at: NodePath) -> void:
	Feel.burst(&"dust", (get_node(at) as Node3D).global_position, Vector3.UP)


func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _process(delta: float) -> void:
	if not playing:
		return
	var holding := SKIP_ACTIONS.any(func(action: StringName) -> bool: return Input.is_action_pressed(action))
	_held = _held + delta if holding else 0.0
	skip_ring.progress = clampf(_held / skip_hold, 0.0, 1.0)
	if _held >= skip_hold:
		skip()
		return
	_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
	_shake_time += delta * 30.0
	var shake := _trauma * _trauma
	camera.h_offset = max_shake.x * shake * sin(_shake_time * 1.7)
	camera.v_offset = max_shake.y * shake * sin(_shake_time * 2.3)


func _finish() -> void:
	playing = false
	skip_hint.visible = false
	var game_camera := _game_camera()
	if game_camera:
		game_camera.call(&"snap_to_target")
		var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(camera, ^"global_transform", game_camera.global_transform, settle_time)
		tween.tween_property(camera, ^"fov", game_camera.fov, settle_time)
	outro.speed_scale = outro.get_animation(&"settle").length / settle_time
	outro.play(&"settle")
	await outro.animation_finished
	_restore()
	finished.emit()
	queue_free()


func _restore() -> void:
	var game_camera := _game_camera()
	if game_camera:
		game_camera.make_current()
	_set_gameplay(true)


func _game_camera() -> Camera3D:
	return get_tree().get_first_node_in_group(TopDownCamera.GROUP) as Camera3D


func _set_gameplay(on: bool) -> void:
	for each in Players.all:
		each.controls.captured = not on
	for hud in get_tree().get_nodes_in_group(Hud.GROUP):
		hud.visible = on
	var game_camera := _game_camera() as TopDownCamera
	if game_camera:
		game_camera.set_cinematic(not on)
