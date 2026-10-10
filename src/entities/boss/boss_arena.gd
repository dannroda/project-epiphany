class_name BossArena
extends Node
## La guarida: al entrar se cierra la puerta, corre la intro (cámara al ojo, nombre, música) y arranca la pelea.
## La intro se salta con aceptar/atacar/interactuar. Al morir el player se recarga la escena y todo vuelve a empezar.
## Vencido: flag `d1_boss_defeated` (abre el portal de salida), la sala se calma y aparece el contenedor de corazón;
## al tomarlo, la pantalla de fin. Al volver a cargar el jefe ya no está.

signal fight_started

const DEFEATED_FLAG := &"d1_boss_defeated"
const CONTAINER_FLAG := &"d1_heart_container"
const PICKUP := preload("res://src/world/pickup.tscn")
const HEART_CONTAINER := preload("res://data/items/heart_container.tres")
## El doom de la sala con el jefe vencido.
const CALM_DOOM := 0.2

const SKIP_ACTIONS: Array[StringName] = [&"ui_accept", &"attack", &"interact"]

@export var room: Room
@export var boss: Boss
@export var door: Door
## Lo que dura la intro con la cámara en el ojo.
@export var intro_hold := 2.6
## Espera a que el player termine de entrar (el deslizamiento de la cámara) antes de cerrar.
@export var close_delay := 0.6
## Dónde aparece el contenedor (relativo al jefe).
@export var reward_offset := Vector3(0, 0, 3.5)

var started := false
var in_intro := false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	if GameState.get_flag(DEFEATED_FLAG) == true:
		_already_won()
		return
	var bounds := room.bounds().grow(-1.5)
	var north := boss.global_position.z - 1.0
	boss.arena = Rect2(bounds.position.x, north, bounds.size.x, bounds.end.y - north)
	room.player_entered.connect(func(_room: Room) -> void: _begin())
	boss.defeated.connect(_on_defeated)
	boss.death_finished.connect(_on_death_finished)


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
	get_tree().call_group(&"hud", &"hide_boss")


func _on_death_finished() -> void:
	GameState.set_flag(DEFEATED_FLAG, true)
	room.doom = CALM_DOOM
	door.open()
	var reward_point := boss.global_position + reward_offset
	boss.queue_free()
	_spawn_reward(reward_point)
	Feel.sfx(&"secret", reward_point)
	SaveManager.autosave()


func _already_won() -> void:
	started = true
	room.doom = CALM_DOOM
	var reward_point := boss.global_position + reward_offset
	boss.queue_free()
	if GameState.get_flag(CONTAINER_FLAG) != true:
		_spawn_reward(reward_point)


func _spawn_reward(point: Vector3) -> void:
	var pickup: Pickup = PICKUP.instantiate()
	pickup.item = HEART_CONTAINER
	pickup.item_get = true
	pickup.lifetime = 0.0
	pickup.magnet_radius = 0.0
	pickup.world_size = 1.4
	add_child(pickup)
	pickup.global_position = point
	pickup.collected.connect(_on_reward_taken)


## Después de la caja de item get, el fin.
func _on_reward_taken() -> void:
	GameState.set_flag(CONTAINER_FLAG, true)
	await get_tree().create_timer(0.3).timeout
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	while MenuStack.is_open() or (player and player.movement_state.get_active_state().name == &"ItemGet"):
		await get_tree().process_frame
	Ending.open()


func _exit_tree() -> void:
	Music.boss_fight = false
