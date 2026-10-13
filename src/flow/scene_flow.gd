# Autoload (scene_flow.tscn)
extends CanvasLayer
## Cambios de escena: viaje por portal, reaparecer, partida nueva, entrar a la escena de una partida, salir al título,
## ubicar a los players y los fundidos. Si la escena tarda en cargar, muestra la pantalla de carga (mockup Loading).
## SaveManager solo lee y escribe partidas.

const TITLE := "res://src/ui/title/title_screen.tscn"
const NEW_GAME_SCENE := "res://levels/overworld.tscn"
const INTRO := preload("res://src/cutscene/intro.tscn")
## Separación entre players al reaparecer juntos (co-op).
const PLAYER_SPACING := 1.2

## Cuánto tiene que tardar la carga para que aparezca la pantalla, y cuánto queda como mínimo (sin parpadeos).
@export var show_loading_after := 0.25
@export var loading_min_time := 0.6

var traveling := false

@onready var _rect: ColorRect = $Rect
@onready var loading_screen: Control = $Loading


func fade_out(seconds: float = 0.4) -> void:
	await _fade(1.0, seconds)


func fade_in(seconds: float = 0.4) -> void:
	await _fade(0.0, seconds)


func _fade(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", alpha, seconds)
	await tween.finished


## Fundido a negro, `action` (cargar, partida nueva…) y fundido de vuelta. Corre acá y no en la pantalla que la pide,
## porque esa pantalla se libera al cambiar de escena y el fundido de vuelta nunca llegaría.
func with_fade(action: Callable) -> void:
	await fade_out(0.3)
	await action.call()
	await fade_in(0.3)


## Cambio de escena por un portal: fundido, carga en segundo plano (con pantalla de carga si tarda), los players en
## `spawn` de la escena nueva y autosave. El juego queda en pausa mientras dura.
func travel_to(scene_path: String, spawn: StringName) -> void:
	traveling = true
	get_tree().paused = true
	ResourceLoader.load_threaded_request(scene_path)
	await fade_out(0.3)
	for player in Players.all:
		GameState.set_ward_of(player.controls.slot, player.health.ward_left())
	if not await _change_scene(scene_path):
		get_tree().paused = false
		await fade_in(0.3)
		traveling = false
		return
	GameState.spawn_scene = scene_path
	GameState.spawn_point = spawn
	GameState.room_entry = null
	GameState.player_position = null
	_place_at_spawn()
	SaveManager.autosave()
	Log.info(&"flow", "Viaje a", scene_path, spawn)
	get_tree().paused = false
	await fade_in(0.3)
	traveling = false


## Carga `scene_path` en un hilo (pedido antes o acá) y cambia de escena. Si tarda más de `show_loading_after`,
## aparece la pantalla de carga (el ojo y "Cargando…" en la esquina).
func _change_scene(scene_path: String) -> bool:
	if ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(scene_path)
	var started := Time.get_ticks_msec()
	var shown_at := -1
	while ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if shown_at < 0 and Time.get_ticks_msec() - started >= show_loading_after * 1000.0:
			shown_at = Time.get_ticks_msec()
			show_loading()
		await get_tree().process_frame
	if shown_at < 0 and show_loading_after <= 0.0:
		shown_at = Time.get_ticks_msec()
		show_loading()
	var packed := ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if shown_at >= 0:
		while Time.get_ticks_msec() - shown_at < loading_min_time * 1000.0:
			await get_tree().process_frame
	if packed == null:
		hide_loading()
		Log.error(&"flow", "No se pudo cargar", scene_path)
		return false
	get_tree().change_scene_to_packed(packed)
	await get_tree().scene_changed
	hide_loading()
	return true


func show_loading() -> void:
	loading_screen.visible = true


func hide_loading() -> void:
	loading_screen.visible = false


## Fundido, recarga la escena y pone al player en el punto de reaparición con la vida llena.
func respawn() -> void:
	await fade_out()
	get_tree().reload_current_scene()
	await get_tree().scene_changed
	_place_at_spawn()
	Log.info(&"combat", "Reapareció en", GameState.spawn_point if GameState.spawn_point else &"(el primero)")
	await fade_in()


## Partida nueva: equipo inicial, en el claro del inicio del overworld. Ocupa su ranura enseguida.
## `with_intro`: la intro (tarea 10.20) arranca sobre el overworld; queda vista apenas empieza.
func new_game(slot: int = -1, with_intro := false) -> Error:
	if slot >= 0:
		SaveManager.current_slot = slot
	GameState.reset()
	GameState.spawn_scene = NEW_GAME_SCENE
	GameState.spawn_point = &"start"
	GameState.player_position = null
	await enter_saved_scene()
	if with_intro:
		GameState.set_flag(&"ow_intro_seen", true)
		get_tree().current_scene.add_child(INTRO.instantiate())
	SaveManager.save_game()
	SaveManager.autosave()
	return OK


func quit_to_title() -> void:
	while MenuStack.is_open():
		MenuStack.pop()
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE)
	await get_tree().scene_changed


## La escena y el lugar que dice GameState (al cargar una partida o empezar una nueva).
## Siempre se recarga, aunque sea la misma: puertas e interruptores arrancan con los flags de la partida.
## Mientras carga, la escena vieja queda en pausa (que no maten al player en el medio).
func enter_saved_scene() -> void:
	if not GameState.spawn_scene.is_empty() and not ResourceLoader.exists(GameState.spawn_scene):
		Log.error(&"flow", "La escena de la partida ya no existe:", GameState.spawn_scene)
		GameState.spawn_scene = NEW_GAME_SCENE
		GameState.spawn_point = &"start"
		GameState.player_position = null
	traveling = true
	get_tree().paused = true
	var changed := true
	if not GameState.spawn_scene.is_empty():
		changed = await _change_scene(GameState.spawn_scene)
	get_tree().paused = MenuStack.is_open()
	if not changed:
		traveling = false
		return
	if not Players.all.is_empty() and GameState.player_position != null:
		place_players(GameState.player_position)
	elif GameState.spawn_point != &"":
		_place_at_spawn()
	await get_tree().physics_frame
	traveling = false


## En mazmorra, en la entrada de la última sala; si no, en el punto de reaparición.
func _place_at_spawn() -> void:
	if Players.all.is_empty():
		return
	get_tree().call_group(&"room_camera", &"reset_room")
	if GameState.current_dungeon != &"" and GameState.room_entry != null:
		place_players(GameState.room_entry)
		get_tree().call_group(&"room_camera", &"snap_to_target")
		return
	var point := SpawnPoint.find(get_tree(), GameState.spawn_point)
	if point:
		place_players(point.global_position)
	get_tree().call_group(&"room_camera", &"snap_to_target")


## El primero en `at` y los demás en fila al costado.
func place_players(at: Vector3) -> void:
	for i in Players.all.size():
		var player := Players.all[i]
		player.global_position = at + Vector3.RIGHT * PLAYER_SPACING * i
		player.velocity = Vector3.ZERO


## Dónde está el player, para la pantalla de ranuras: "Mazmorra · Sala" o la zona del overworld, sin traducir
## (claves PLACE_* que `SlotCard` traduce al mostrar).
func location() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	for child in scene.get_children():
		if child is Dungeon:
			var camera := get_tree().get_first_node_in_group(&"room_camera") as TopDownCamera
			var room_name := camera.room.display_name if camera and camera.room else ""
			return child.display_name + (" · " + room_name if not room_name.is_empty() else "")
	var player := Players.lead()
	for child in scene.get_children():
		if child is AreaZone and player and (child as AreaZone).contains(player.global_position):
			return child.display_name
	for child in scene.get_children():
		if child is OverworldMap:
			return child.display_name
	return ""
