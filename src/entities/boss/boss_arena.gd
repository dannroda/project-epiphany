@tool
class_name BossArena
extends Node
## La guarida: al entrar se cierra la puerta, corre la intro (cámara al ojo, nombre, música) y arranca la pelea.
## La intro se salta con aceptar/atacar/interactuar. Al morir el player se recarga la escena y todo vuelve a empezar.
## Vencido: `defeated_flag` (abre el portal de salida), la sala se calma y aparece el contenedor de corazón.
## La puerta queda cerrada: el portal es la única salida y entrar abre el fin de la demo. Al volver a cargar el jefe
## ya no está, salvo en la revancha (`GameState.boss_rematch`): pelea completa, sin otro contenedor.

signal fight_started

## El doom de la sala con el jefe vencido.
const CALM_DOOM := 0.2


@export var room: Room
@export var defeated_flag: StringName:
	set(value):
		defeated_flag = value
		update_configuration_warnings()
@export var container_flag: StringName:
	set(value):
		container_flag = value
		update_configuration_warnings()
## Lo que aparece al vencerlo (una vez, por `container_flag`).
@export var reward: ItemData:
	set(value):
		reward = value
		update_configuration_warnings()
## El diálogo al entrar al portal de salida.
@export var ending: DialogueResource:
	set(value):
		ending = value
		update_configuration_warnings()
@export var boss: Boss
@export var door: Door
@export var exit_portal: Portal
## Lo que dura la intro con la cámara en el ojo.
@export var intro_hold := 2.6
## Espera a que el player termine de entrar (el deslizamiento de la cámara) antes de cerrar.
@export var close_delay := 0.6
## Dónde aparece el contenedor (relativo al jefe).
@export var reward_offset := Vector3(0, 0, 3.5)
## En la revancha, cuánto adentro de la puerta aparece el player.
@export var rematch_entry_depth := 2.5

var started := false
var in_intro := false
## La respuesta del diálogo de fin (la escribe ending.dialogue).
var ending_choice := ""


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_mode = PROCESS_MODE_ALWAYS
	exit_portal.player_entered.connect(_on_exit)
	if GameState.get_flag(defeated_flag) == true and not GameState.boss_rematch:
		_already_won()
		return
	boss.arena = room.bounds().grow(-1.5)
	room.player_entered.connect(func(_room: Room) -> void: _begin())
	boss.defeated.connect(_on_defeated)
	boss.death_finished.connect(_on_death_finished)
	if GameState.boss_rematch:
		exit_portal.held = true
		_begin.call_deferred()


func _begin() -> void:
	if started:
		return
	started = true
	await Tweens.wait(self, close_delay)
	door.close()
	await Tweens.wait(self, door.open_time)
	in_intro = true
	boss.presents_phases = true
	Music.boss_fight = true
	_sharpen()
	await TopDownCamera.reveal(boss.eye, _awaken, intro_hold)
	in_intro = false
	get_tree().call_group(Hud.GROUP, &"show_boss", boss)
	boss.start_fight()
	fight_started.emit()


## El jefe flota alto: sin el desenfoque de cerca de la cámara (EnfoqueLA) se lo ve nítido. Copia los atributos para
## no tocar los de la escena.
func _sharpen() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera and camera.attributes is CameraAttributesPractical:
		camera.attributes = camera.attributes.duplicate()
		(camera.attributes as CameraAttributesPractical).dof_blur_near_enabled = false


func _awaken() -> void:
	get_tree().call_group(Hud.GROUP, &"show_area_name", tr(boss.display_name))
	Feel.sfx(&"rumble", boss.eye.global_position, true)
	Feel.shake(0.35)
	var player := Players.nearest(boss.eye.global_position)
	if player:
		boss.look_at_point(boss.gaze_point(player.global_position))
	boss.roar()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PersistentFlag.warnings_for(defeated_flag, false, self)
	warnings.append_array(PersistentFlag.warnings_for(container_flag, false, self))
	if reward == null:
		warnings.append("Falta el premio (reward).")
	if ending == null:
		warnings.append("Falta el diálogo de fin (ending).")
	return warnings


func _on_defeated() -> void:
	Music.boss_fight = false
	get_tree().call_group(Hud.GROUP, &"hide_boss")


func _on_death_finished() -> void:
	GameState.set_flag(defeated_flag, true)
	room.doom = CALM_DOOM
	var reward_point := boss.global_position + reward_offset
	boss.queue_free()
	if GameState.get_flag(container_flag) != true:
		_spawn_reward(reward_point)
	Feel.sfx(&"secret", reward_point)
	if GameState.boss_rematch:
		GameState.boss_rematch = false
		exit_portal.held = false
	SaveManager.autosave()


func _already_won() -> void:
	started = true
	room.doom = CALM_DOOM
	door.close(false)
	var reward_point := boss.global_position + reward_offset
	boss.queue_free()
	if GameState.get_flag(container_flag) != true:
		_spawn_reward(reward_point)


func _spawn_reward(point: Vector3) -> void:
	var pickup := Pickup.make(reward)
	pickup.item_get = true
	pickup.lifetime = 0.0
	pickup.magnet_radius = 0.0
	pickup.world_size = 1.4
	Spawns.root(self).add_child(pickup)
	pickup.global_position = point
	pickup.collected.connect(_on_reward_taken)


func _on_reward_taken() -> void:
	GameState.set_flag(container_flag, true)


## Vuelve a cargar la arena con el jefe vivo; el player aparece adentro, junto a la puerta.
func start_rematch() -> void:
	GameState.boss_rematch = true
	GameState.room_entry = door.global_position + Vector3.FORWARD * rematch_entry_depth
	SceneFlow.respawn()


func _on_exit(_player: PlayerCharacter) -> void:
	if MenuStack.is_open():
		return
	SaveManager.autosave(false)
	ending_choice = ""
	await TextBox.open(ending, "start", TextBox.Style.ITEM, [self]).finished
	match ending_choice:
		"keep_playing":
			exit_portal.travel()
		"rematch":
			start_rematch()
		"to_title":
			SaveManager.save_checkpoint()
			SceneFlow.quit_to_title()


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		Music.boss_fight = false
