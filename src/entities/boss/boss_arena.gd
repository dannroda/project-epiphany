class_name BossArena
extends Node
## La guarida: al entrar se cierra la puerta, corre la intro (cámara al ojo, nombre, música) y arranca la pelea.
## La intro se salta con aceptar/atacar/interactuar. Al morir el player se recarga la escena y todo vuelve a empezar.

signal fight_started

const SKIP_ACTIONS: Array[StringName] = [&"ui_accept", &"attack", &"interact"]

@export var room: Room
@export var boss: Boss
@export var door: Door
## Lo que dura la intro con la cámara en el ojo.
@export var intro_hold := 2.6
## Espera a que el player termine de entrar (el deslizamiento de la cámara) antes de cerrar.
@export var close_delay := 0.6

var started := false
var in_intro := false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	room.player_entered.connect(func(_room: Room) -> void: _begin())
	boss.defeated.connect(_on_defeated)


func _begin() -> void:
	if started:
		return
	started = true
	await get_tree().create_timer(close_delay, false).timeout
	door.close()
	await get_tree().create_timer(door.open_time, false).timeout
	in_intro = true
	Music.boss_fight = true
	await TopDownCamera.reveal(boss.eye, _awaken, intro_hold)
	in_intro = false
	get_tree().call_group(&"hud", &"show_boss", boss)
	boss.start_fight()
	fight_started.emit()


func _awaken() -> void:
	get_tree().call_group(&"hud", &"show_area_name", tr(boss.display_name))
	Feel.sfx(&"rumble", boss.eye.global_position)
	Feel.shake(0.35)
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player:
		boss.look_at_point(player.global_position + Vector3.UP)
	var blink := boss.eye.create_tween()
	blink.tween_property(boss, ^"eye_open", 0.4, 0.5).set_delay(0.3)
	blink.tween_property(boss, ^"eye_open", 0.0, 0.3).set_delay(0.8)


func _unhandled_input(event: InputEvent) -> void:
	if not in_intro:
		return
	for action in SKIP_ACTIONS:
		if event.is_action_pressed(action):
			get_tree().call_group(&"room_camera", &"skip_reveal")
			get_viewport().set_input_as_handled()
			return


func _on_defeated() -> void:
	Music.boss_fight = false
	door.open()
	get_tree().call_group(&"hud", &"hide_boss")


func _exit_tree() -> void:
	Music.boss_fight = false
