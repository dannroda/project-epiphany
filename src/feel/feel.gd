# Autoload
extends Node
## Feedback: hit-stop, sacudida, vibración, partículas y sonidos. Cada evento tiene varias muestras (packs CC0 de
## Kenney en assets/audio/sfx/) y suena con tono y volumen al azar; los que no tienen muestra se sintetizan.

const SFX_BUS := &"SFX"
const UI_BUS := &"UI"
const MIX_RATE := 22050
const SAMPLE_DIR := "res://assets/audio/sfx/"
const VOLUME_VARIATION_DB := 1.5
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
}

var settings: FeelSettings = preload("res://data/feel.tres")
var _sounds: Dictionary[StringName, Array] = {}
var _menu_depth := 0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(SFX_BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, SFX_BUS)
	_sounds = {
		&"hit": [_synth(0.09, func(t: float) -> float: return (randf() * 2.0 - 1.0) * 0.6 * exp(-t * 40.0) + sin(TAU * 110.0 * t) * exp(-t * 25.0))],
		&"hurt": [_synth(0.16, func(t: float) -> float: return signf(sin(TAU * lerpf(240.0, 110.0, t / 0.16) * t)) * 0.35 * exp(-t * 14.0))],
		&"block": [_synth(0.2, func(t: float) -> float: return (sin(TAU * 1400.0 * t) + 0.6 * sin(TAU * 2150.0 * t)) * 0.4 * exp(-t * 22.0))],
		&"click": [_synth(0.04, func(t: float) -> float: return sin(TAU * 1800.0 * t) * 0.3 * exp(-t * 90.0))],
		&"roll": [_synth(0.25, func(t: float) -> float: return (randf() * 2.0 - 1.0) * 0.25 * sin(PI * t / 0.25))],
		&"pickup": [_synth(0.14, func(t: float) -> float: return sin(TAU * (880.0 if t < 0.06 else 1320.0) * t) * 0.25 * exp(-fmod(t, 0.06) * 30.0))],
		&"break": [_synth(0.22, func(t: float) -> float: return (randf() * 2.0 - 1.0) * 0.5 * exp(-t * 18.0) + sin(TAU * 620.0 * t) * 0.2 * exp(-t * 30.0))],
		&"cut": [_synth(0.12, func(t: float) -> float: return (randf() * 2.0 - 1.0) * 0.3 * sin(PI * t / 0.12))],
		&"reflect": [_synth(0.3, func(t: float) -> float: return (sin(TAU * 1760.0 * t) + 0.5 * sin(TAU * 2640.0 * t)) * 0.3 * exp(-t * 9.0))],
		&"boom": [_synth(0.6, func(t: float) -> float: return ((randf() * 2.0 - 1.0) * 0.7 + sin(TAU * lerpf(90.0, 40.0, t / 0.6) * t) * 0.5) * exp(-t * 6.0))],
		&"secret": [_synth(0.9, func(t: float) -> float: return sin(TAU * [392.0, 440.0, 523.0, 659.0, 784.0, 1047.0][mini(int(t / 0.15), 5)] * t) * 0.25 * exp(-fmod(t, 0.15) * 6.0))],
		&"door": [_synth(0.55, func(t: float) -> float: return ((randf() * 2.0 - 1.0) * 0.35 + sin(TAU * 55.0 * t) * 0.3) * sin(PI * t / 0.55))],
		&"deny": [_synth(0.18, func(t: float) -> float: return signf(sin(TAU * (140.0 if t < 0.08 else 105.0) * t)) * 0.25 * (1.0 if fmod(t, 0.09) < 0.07 else 0.0))],
		&"rumble": [_synth(1.2, func(t: float) -> float: return ((randf() * 2.0 - 1.0) * 0.3 + sin(TAU * 38.0 * t) * 0.45) * sin(PI * t / 1.2))],
		&"item_get": [_synth(1.3, func(t: float) -> float: return 0.22 * (sin(TAU * [392.0, 523.0, 659.0, 784.0][mini(int(t / 0.09), 3)] * t) * exp(-fmod(t, 0.09) * 10.0) if t < 0.36 else (sin(TAU * 1047.0 * t) + 0.7 * sin(TAU * 1319.0 * t) + 0.5 * sin(TAU * 1568.0 * t)) * 0.5 * exp(-(t - 0.36) * 2.5) * minf(1.0, (t - 0.36) * 60.0)))],
		&"drip": [_synth(0.12, func(t: float) -> float: return sin(TAU * lerpf(700.0, 1700.0, minf(t / 0.04, 1.0)) * t) * 0.3 * exp(-t * 35.0))],
		&"splash": [_synth(0.45, func(t: float) -> float: return ((randf() * 2.0 - 1.0) * 0.45 * exp(-t * 9.0) + sin(TAU * lerpf(160.0, 70.0, t / 0.45) * t) * 0.35 * exp(-t * 14.0)) * minf(1.0, t * 200.0))],
		&"wade": [_synth(0.16, func(t: float) -> float: return (randf() * 2.0 - 1.0) * 0.18 * sin(PI * t / 0.16) * exp(-t * 8.0))],
		&"roar": [_synth(1.4, func(t: float) -> float: return (fmod(lerpf(70.0, 125.0, sin(PI * t / 1.4)) * t, 1.0) * 0.7 - 0.35 + (randf() * 2.0 - 1.0) * 0.28) * (0.7 + 0.3 * sin(TAU * 27.0 * t)) * minf(1.0, t * 12.0) * minf(1.0, (1.4 - t) * 2.5))],
		&"warp_out": [_synth(0.55, func(t: float) -> float: return signf(sin(TAU * lerpf(220.0, 1500.0, pow(t / 0.55, 1.5)) * t)) * 0.16 * (0.6 + 0.4 * sin(TAU * 30.0 * t)) * minf(1.0, (0.55 - t) * 8.0))],
		&"warp_in": [_synth(0.5, func(t: float) -> float: return signf(sin(TAU * lerpf(1500.0, 260.0, minf(t / 0.2, 1.0)) * t)) * 0.16 * minf(1.0, t * 80.0) * exp(-maxf(t - 0.2, 0.0) * 9.0) + sin(TAU * 70.0 * t) * 0.35 * exp(-maxf(t - 0.18, 0.0) * 14.0) * (1.0 if t > 0.18 else 0.0))],
		&"heal": [_synth(0.45, func(t: float) -> float: return sin(TAU * [523.0, 659.0, 784.0][mini(int(t / 0.15), 2)] * t) * 0.3 * exp(-fmod(t, 0.15) * 12.0))],
	}
	for sound in SAMPLES:
		var streams := _load_samples(SAMPLES[sound])
		if not streams.is_empty():
			_sounds[sound] = streams
	get_viewport().gui_focus_changed.connect(func(control: Control) -> void:
		if control is BaseButton or control is Range:
			ui(&"ui_move"))
	MenuStack.changed.connect(_on_menus_changed)


func _input(event: InputEvent) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if event.is_action_pressed(&"ui_accept") and focused is BaseButton:
		ui(&"ui_accept")
	elif event.is_action_pressed(&"ui_cancel") and focused != null:
		ui(&"ui_back")


func _on_menus_changed() -> void:
	var depth := MenuStack.depth()
	ui(&"ui_open" if depth > _menu_depth else &"ui_close")
	_menu_depth = depth


## Sonido de interfaz (sin posición, bus UI).
func ui(sound: StringName) -> void:
	var streams: Array = _sounds.get(sound, [])
	if streams.is_empty():
		return
	var player := UI_SOUND.instantiate() as AudioStreamPlayer
	player.stream = streams.pick_random()
	player.volume_db = settings.sfx_volume_db - 4.0
	player.pitch_scale = 1.0 + randf_range(-0.04, 0.04)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _load_samples(prefixes: Array) -> Array:
	var streams := []
	for prefix: String in prefixes:
		var folder := SAMPLE_DIR + prefix.get_base_dir()
		var start := prefix.get_file()
		for file in ResourceLoader.list_directory(folder):
			if file.begins_with(start) and file.ends_with(".ogg"):
				streams.append(load(folder.path_join(file)))
	return streams


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
	if duration <= 0.0 or Engine.time_scale < 1.0:
		return
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


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
	var streams: Array = _sounds.get(sound, [])
	var scene := get_tree().current_scene
	if streams.is_empty() or scene == null:
		return
	var player := SFX_PLAYER.instantiate() as AudioStreamPlayer3D
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


func _synth(seconds: float, wave: Callable) -> AudioStreamWAV:
	var samples := int(seconds * MIX_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var value := clampf(wave.call(float(i) / MIX_RATE), -1.0, 1.0)
		data.encode_s16(i * 2, int(value * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = data
	return stream


## Vibración del gamepad, proporcional al golpe (Opciones › Vibración). `pads`: los del player al que le pasa;
## vacío (algo del mundo, o un player que usa cualquier pad) vibran todos.
func rumble(amount: float, pads: Array[int] = []) -> void:
	if not Settings.get_value(&"vibration"):
		return
	var strength := clampf(amount, 0.0, 1.0)
	for pad in (pads if not pads.is_empty() else Input.get_connected_joypads()):
		Input.start_joy_vibration(pad, strength * 0.6, strength, 0.12 + strength * 0.25)
