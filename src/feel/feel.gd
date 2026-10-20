# Autoload
extends Node
## Feedback: hit-stop, sacudida, vibración, partículas y sonidos. Cada evento tiene varias muestras (packs CC0 de
## Kenney en assets/audio/sfx/; las del jefe, en boss/, salen de tools/audio/render_boss_sfx.py) y suena con tono y
## volumen al azar; los que no tienen muestra se sintetizan.

const SFX_BUS := &"SFX"
const UI_BUS := &"UI"
const SAMPLE_DIR := "res://assets/audio/sfx/"
const VOLUME_VARIATION_DB := 1.5
## Sonidos del mundo a la vez: con más, el más viejo se corta.
const MAX_VOICES := 24
## Copias del mismo sonido en un cuadro (N enemigos golpeados a la vez suenan como uno fuerte, no saturan).
const MAX_SAME_PER_FRAME := 3
const SFX_PLAYER := preload("res://src/feel/sfx_player.tscn")
const UI_SOUND := preload("res://src/feel/ui_sound.tscn")
const SHOCKWAVE := preload("res://src/feel/shockwave.tscn")
## Una escena por ráfaga (src/feel/bursts/): ahí se tocan cantidad, vida, colores y forma.
const BURSTS: Dictionary[StringName, PackedScene] = {
	&"sparks": preload("res://src/feel/bursts/sparks.tscn"),
	&"sparks_gold": preload("res://src/feel/bursts/sparks_gold.tscn"),
	&"sparkle": preload("res://src/feel/bursts/sparkle.tscn"),
	&"explosion": preload("res://src/feel/bursts/explosion.tscn"),
	&"shards": preload("res://src/feel/bursts/shards.tscn"),
	&"leaves": preload("res://src/feel/bursts/leaves.tscn"),
	&"dust": preload("res://src/feel/bursts/dust.tscn"),
	&"splash": preload("res://src/feel/bursts/splash.tscn"),
	&"wade": preload("res://src/feel/bursts/wade.tscn"),
}
## Evento → prefijos de archivo (carpeta/nombre) dentro de SAMPLE_DIR.
const SAMPLES := {
	&"hit": ["kenney_impact-sounds/impactPunch_medium_"],
	&"hit_flesh": ["kenney_impact-sounds/impactPunch_medium_"],
	&"hit_metal": ["kenney_impact-sounds/impactPlate_medium_"],
	&"hit_stone": ["kenney_impact-sounds/impactMining_"],
	&"hurt": ["kenney_impact-sounds/impactPunch_heavy_"],
	&"block": ["kenney_impact-sounds/impactMetal_medium_"],
	&"click": ["kenney_rpg-audio/metalClick", "kenney_rpg-audio/metalLatch"],
	&"roll": ["kenney_rpg-audio/cloth"],
	&"pickup": ["kenney_interface-sounds/confirmation_"],
	&"break": ["kenney_impact-sounds/impactGlass_medium_"],
	&"cut": ["kenney_rpg-audio/knifeSlice", "kenney_rpg-audio/chop"],
	&"reflect": ["kenney_impact-sounds/impactBell_heavy_"],
	&"door": ["kenney_rpg-audio/doorOpen_"],
	&"stairs": ["kenney_rpg-audio/footstep0"],
	&"deny": ["kenney_interface-sounds/error_"],
	&"ui_move": ["kenney_interface-sounds/tick_"],
	&"ui_accept": ["kenney_interface-sounds/select_"],
	&"ui_back": ["kenney_interface-sounds/back_"],
	&"ui_open": ["kenney_interface-sounds/open_"],
	&"ui_close": ["kenney_interface-sounds/close_"],
	&"boss_lid": ["boss/boss_lid_"],
	&"boss_roar": ["boss/boss_roar"],
	&"boss_slam": ["boss/boss_slam_"],
	&"boss_eye_hit": ["boss/boss_eye_hit_"],
	&"boom": ["synth/boom"],
	&"secret": ["synth/secret"],
	&"rumble": ["synth/rumble"],
	&"item_get": ["synth/item_get"],
	&"drip": ["synth/drip"],
	&"splash": ["synth/splash"],
	&"wade": ["synth/wade"],
	&"roar": ["synth/roar"],
	&"warp_out": ["synth/warp_out"],
	&"warp_in": ["synth/warp_in"],
	&"heal": ["synth/heal"],
}

var settings: FeelSettings = preload("res://data/feel.tres")
var _sounds: Dictionary[StringName, Array] = {}
var _menu_depth := 0
var _voices: Array[AudioStreamPlayer3D] = []
var _frame := -1
var _same_frame: Dictionary[StringName, int] = {}


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	get_viewport().gui_focus_changed.connect(func(control: Control) -> void:
		if control is BaseButton or control is Range:
			ui(&"ui_move")
		if control is BaseButton and not (control as BaseButton).pressed.is_connected(_on_button_pressed):
			(control as BaseButton).pressed.connect(_on_button_pressed))
	MenuStack.changed.connect(_on_menus_changed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and get_viewport().gui_get_focus_owner() != null:
		ui(&"ui_back")


func _on_button_pressed() -> void:
	ui(&"ui_accept")


func _on_menus_changed() -> void:
	var depth := MenuStack.depth()
	ui(&"ui_open" if depth > _menu_depth else &"ui_close")
	_menu_depth = depth


## Sonido de interfaz (sin posición, bus UI).
func ui(sound: StringName) -> void:
	var streams := streams_of(sound)
	if streams.is_empty():
		return
	var player := UI_SOUND.instantiate() as AudioStreamPlayer
	player.stream = streams.pick_random()
	player.volume_db = settings.sfx_volume_db - 4.0
	player.pitch_scale = 1.0 + randf_range(-0.04, 0.04)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## Las muestras de un evento; se cargan la primera vez que suena.
func streams_of(sound: StringName) -> Array:
	if not _sounds.has(sound):
		var streams := []
		for prefix: String in SAMPLES.get(sound, []):
			var folder := SAMPLE_DIR + prefix.get_base_dir()
			var start := prefix.get_file()
			for file in ResourceLoader.list_directory(folder):
				if file.begins_with(start) and (file.ends_with(".ogg") or file.ends_with(".wav")):
					streams.append(load(folder.path_join(file)))
		_sounds[sound] = streams
	return _sounds[sound]


## Congela a los involucrados un instante (no toca Engine.time_scale).
func hit_stop(nodes: Array, duration: float) -> void:
	if duration <= 0.0:
		return
	var frozen: Array[Node] = []
	for node in nodes:
		if is_instance_valid(node) and node is Node and not node.has_meta(&"hit_stop"):
			node.set_meta(&"hit_stop", node.process_mode)
			node.set_deferred(&"process_mode", PROCESS_MODE_DISABLED)
			frozen.append(node)
	if frozen.is_empty():
		return
	await get_tree().create_timer(duration, true, false, true).timeout
	for node in frozen:
		if is_instance_valid(node):
			node.process_mode = node.get_meta(&"hit_stop")
			node.remove_meta(&"hit_stop")


## Frena todo el juego un rato (golpes grandes, cámara lenta del final). A diferencia de `hit_stop`, la física sigue:
## los golpes conectan. Vive en el autoload para volver a velocidad normal aunque se libere quien lo pidió.
func freeze(duration: float, scale := 0.05) -> void:
	if duration <= 0.0 or TimeScale.is_held(&"freeze"):
		return
	TimeScale.hold(&"freeze", scale)
	await get_tree().create_timer(duration, true, false, true).timeout
	TimeScale.release(&"freeze")


## La opción de accesibilidad (Opciones › temblor de cámara): la decide el jugador, no feel.tres.
func shakes() -> bool:
	return Settings.get_value(&"shake")


## `direction` (mundo): de dónde viene el golpe; el encuadre se empuja hacia ese lado.
func shake(amount: float, direction := Vector3.ZERO, pads: Array[int] = []) -> void:
	rumble(amount, pads)
	if not shakes():
		return
	var camera := get_viewport().get_camera_3d()
	if camera and camera.has_method(&"add_trauma"):
		camera.add_trauma(amount, direction)


## `always`: suena aunque el juego esté en pausa (el acercamiento de la cámara a un jefe).
func sfx(sound: StringName, at: Vector3, always := false) -> void:
	var streams := streams_of(sound)
	var scene := get_tree().current_scene
	if streams.is_empty() or scene == null:
		return
	if Engine.get_process_frames() != _frame:
		_frame = Engine.get_process_frames()
		_same_frame.clear()
	if _same_frame.get(sound, 0) >= MAX_SAME_PER_FRAME:
		return
	_same_frame[sound] = _same_frame.get(sound, 0) + 1
	for i in range(_voices.size() - 1, -1, -1):
		if not is_instance_valid(_voices[i]) or _voices[i].is_queued_for_deletion():
			_voices.remove_at(i)
	if _voices.size() >= MAX_VOICES:
		_voices.pop_front().queue_free()
	var player := SFX_PLAYER.instantiate() as AudioStreamPlayer3D
	_voices.append(player)
	player.stream = streams.pick_random()
	player.volume_db = settings.sfx_volume_db + randf_range(-VOLUME_VARIATION_DB, VOLUME_VARIATION_DB)
	player.pitch_scale = 1.0 + randf_range(-settings.pitch_variation, settings.pitch_variation)
	scene.add_child(player)
	player.global_position = at
	if always:
		player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.finished.connect(player.queue_free)
	player.play()


## Prende o apaga una estela. Trail3D no desvanece lo que queda al dejar de emitir ni lo separa del tramo siguiente:
## se limpia al prender y cuando termina de apagarse.
func set_trail(trail: Trail3D, on: bool) -> void:
	if on:
		trail.clear()
	else:
		var id := trail.get_instance_id()
		get_tree().create_timer(trail.lifetime, false).timeout.connect(func() -> void:
			var left := instance_from_id(id) as Trail3D
			if left and not left.emitting:
				left.clear())
	trail.emitting = on


## Partículas cortas, todas low poly con colores de la paleta y achicándose al morir: &"sparks" (bloqueo, rebote; &"sparks_gold" al pegar con la espada dorada),
## &"dust" (rodar, golpes contra el piso), &"shards" (algo que se rompe), &"leaves" (pasto), &"explosion" (bomba),
## &"sparkle" (destello del item get).
## `always`: anda aunque el juego esté en pausa, como en `sfx`.
func burst(kind: StringName, at: Vector3, direction: Vector3, always := false) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var particles := BURSTS.get(kind, BURSTS[&"dust"]).instantiate() as CPUParticles3D
	particles.direction = direction
	if always:
		particles.process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	if kind == &"explosion":
		_shockwave(scene, at, always)


## Anillo plano que se abre a ras del piso con la explosión.
func _shockwave(scene: Node, at: Vector3, always := false) -> void:
	var ring := SHOCKWAVE.instantiate() as MeshInstance3D
	if always:
		ring.process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(ring)
	ring.global_position = Vector3(at.x, at.y - 0.3, at.z)


## Vibración del gamepad, proporcional al golpe (Opciones › Vibración). `pads`: los del player al que le pasa;
## vacío (algo del mundo, o un player que usa cualquier pad) vibran todos.
func rumble(amount: float, pads: Array[int] = []) -> void:
	if not Settings.get_value(&"vibration"):
		return
	var strength := clampf(amount, 0.0, 1.0)
	for pad in (pads if not pads.is_empty() else Input.get_connected_joypads()):
		Input.start_joy_vibration(pad, strength * 0.6, strength, 0.12 + strength * 0.25)
