# Autoload
extends Node
## Feedback: hit-stop, sacudida, vibración, partículas y sonidos. Cada evento tiene varias muestras (packs CC0 de
## Kenney en assets/audio/sfx/) y suena con tono y volumen al azar; los que no tienen muestra se sintetizan.

const SFX_BUS := &"SFX"
const UI_BUS := &"UI"
const MIX_RATE := 22050
const SAMPLE_DIR := "res://assets/audio/sfx/"
const VOLUME_VARIATION_DB := 1.5
## Evento → prefijos de archivo (carpeta/nombre) dentro de SAMPLE_DIR.
const SAMPLES := {
	&"hit": ["kenney_impact-sounds/impactPunch_medium_"],
	&"hurt": ["kenney_impact-sounds/impactPunch_heavy_"],
	&"block": ["kenney_impact-sounds/impactMetal_medium_"],
	&"click": ["kenney_rpg-audio/metalClick", "kenney_rpg-audio/metalLatch"],
	&"roll": ["kenney_rpg-audio/cloth"],
	&"pickup": ["kenney_interface-sounds/confirmation_"],
	&"break": ["kenney_impact-sounds/impactGlass_medium_"],
	&"cut": ["kenney_rpg-audio/knifeSlice", "kenney_rpg-audio/chop"],
	&"reflect": ["kenney_impact-sounds/impactBell_heavy_"],
	&"door": ["kenney_rpg-audio/doorOpen_"],
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
		&"heal": [_synth(0.45, func(t: float) -> float: return sin(TAU * [523.0, 659.0, 784.0][mini(int(t / 0.15), 2)] * t) * 0.3 * exp(-fmod(t, 0.15) * 12.0))],
	}
	for sound in SAMPLES:
		var streams := _load_samples(SAMPLES[sound])
		if not streams.is_empty():
			_sounds[sound] = streams
	get_viewport().gui_focus_changed.connect(func(control: Control) -> void:
		if control is BaseButton or control is Range:
			ui(&"ui_move"))
	(func() -> void:
		var stack := get_node_or_null(^"/root/MenuStack")
		if stack:
			stack.changed.connect(_on_menus_changed.bind(stack))).call_deferred()


func _input(event: InputEvent) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if event.is_action_pressed(&"ui_accept") and focused is BaseButton:
		ui(&"ui_accept")
	elif event.is_action_pressed(&"ui_cancel") and focused != null:
		ui(&"ui_back")


func _on_menus_changed(stack: Node) -> void:
	var depth: int = stack._stack.size()
	ui(&"ui_open" if depth > _menu_depth else &"ui_close")
	_menu_depth = depth


## Sonido de interfaz (sin posición, bus UI).
func ui(sound: StringName) -> void:
	var streams: Array = _sounds.get(sound, [])
	if streams.is_empty():
		return
	var player := AudioStreamPlayer.new()
	player.stream = streams.pick_random()
	player.bus = UI_BUS
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


## `direction` (mundo): de dónde viene el golpe; el encuadre se empuja hacia ese lado.
func shake(amount: float, direction := Vector3.ZERO) -> void:
	rumble(amount)
	if not settings.shake_enabled:
		return
	var camera := get_viewport().get_camera_3d()
	if camera and camera.has_method(&"add_trauma"):
		camera.add_trauma(amount, direction)


func sfx(sound: StringName, at: Vector3) -> void:
	var streams: Array = _sounds.get(sound, [])
	var scene := get_tree().current_scene
	if streams.is_empty() or scene == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = streams.pick_random()
	player.bus = SFX_BUS
	player.volume_db = settings.sfx_volume_db + randf_range(-VOLUME_VARIATION_DB, VOLUME_VARIATION_DB)
	player.pitch_scale = 1.0 + randf_range(-settings.pitch_variation, settings.pitch_variation)
	scene.add_child(player)
	player.global_position = at
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


## Partículas cortas, todas low poly con colores de la paleta y achicándose al morir: &"sparks" (bloqueo, rebote),
## &"dust" (rodar, golpes contra el piso), &"shards" (algo que se rompe), &"leaves" (pasto), &"explosion" (bomba),
## &"sparkle" (destello del item get).
func burst(kind: StringName, at: Vector3, direction: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var particles := _burst_template(kind).duplicate() as CPUParticles3D
	particles.direction = direction
	scene.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	if kind == &"explosion":
		_shockwave(scene, at)


var _bursts: Dictionary[StringName, CPUParticles3D] = {}


func _exit_tree() -> void:
	for template in _bursts.values():
		template.free()
	_bursts.clear()


func _burst_template(kind: StringName) -> CPUParticles3D:
	if _bursts.has(kind):
		return _bursts[kind]
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.scale_amount_curve = _shrink_curve()
	var mesh: PrimitiveMesh
	var color: Color
	match kind:
		&"sparks":
			particles.amount = 14
			particles.lifetime = 0.25
			particles.spread = 70.0
			particles.initial_velocity_min = 3.5
			particles.initial_velocity_max = 6.0
			particles.gravity = Vector3(0, -6, 0)
			particles.particle_flag_align_y = true
			mesh = _gem(0.02, 0.16)
			color = Color(1.0, 0.86, 0.45)
		&"sparkle":
			particles.amount = 16
			particles.lifetime = 0.7
			particles.spread = 180.0
			particles.initial_velocity_min = 1.2
			particles.initial_velocity_max = 2.4
			particles.gravity = Vector3.ZERO
			particles.damping_min = 2.5
			particles.damping_max = 3.5
			particles.angular_velocity_min = -540.0
			particles.angular_velocity_max = 540.0
			mesh = _gem(0.05, 0.14)
			color = Color(1.0, 0.9, 0.55)
		&"explosion":
			particles.amount = 32
			particles.lifetime = 0.55
			particles.spread = 180.0
			particles.initial_velocity_min = 3.0
			particles.initial_velocity_max = 7.0
			particles.gravity = Vector3(0, -3, 0)
			particles.damping_min = 4.0
			particles.damping_max = 6.0
			particles.scale_amount_min = 0.8
			particles.scale_amount_max = 2.2
			particles.color_ramp = _fire_ramp()
			mesh = _gem(0.12, 0.24)
			color = Color.WHITE
		&"shards", &"leaves":
			var leaves := kind == &"leaves"
			particles.amount = 14 if leaves else 10
			particles.lifetime = 0.6
			particles.spread = 80.0
			particles.initial_velocity_min = 1.5
			particles.initial_velocity_max = 3.0
			particles.gravity = Vector3(0, -4 if leaves else -12, 0)
			particles.damping_min = 2.0 if leaves else 0.0
			particles.damping_max = 3.0 if leaves else 0.0
			particles.angular_velocity_min = -360.0
			particles.angular_velocity_max = 360.0
			mesh = _gem(0.06, 0.05) if leaves else _gem(0.07, 0.12)
			color = Color(0.36, 0.62, 0.27) if leaves else Color(0.62, 0.38, 0.24)
		_:
			particles.amount = 10
			particles.lifetime = 0.45
			particles.spread = 45.0
			particles.initial_velocity_min = 0.8
			particles.initial_velocity_max = 1.6
			particles.gravity = Vector3(0, 0.6, 0)
			particles.scale_amount_min = 0.6
			particles.scale_amount_max = 1.2
			mesh = _gem(0.08, 0.14)
			color = Color(0.75, 0.68, 0.58)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	mesh.material = material
	particles.mesh = mesh
	_bursts[kind] = particles
	return particles


## Un octaedro: la partícula low poly de todas las ráfagas.
func _gem(radius: float, height: float) -> PrimitiveMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 4
	mesh.rings = 1
	return mesh


func _shrink_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.6, 0.8))
	curve.add_point(Vector2(1.0, 0.0))
	return curve


func _fire_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.7))
	ramp.set_color(1, Color(0.35, 0.22, 0.2))
	ramp.add_point(0.35, Color(1.0, 0.55, 0.2))
	return ramp


## Anillo plano que se abre a ras del piso con la explosión.
func _shockwave(scene: Node, at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 12
	torus.ring_segments = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.8, 0.5, 0.8)
	torus.material = material
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(ring)
	ring.global_position = Vector3(at.x, at.y - 0.3, at.z)
	ring.scale = Vector3(0.3, 0.15, 0.3)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3(2.6, 0.15, 2.6), 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(ring.queue_free)


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


## Vibración del gamepad, proporcional al golpe (Opciones › Vibración).
func rumble(amount: float) -> void:
	if not Settings.get_value(&"vibration") or Input.get_connected_joypads().is_empty():
		return
	var strength := clampf(amount, 0.0, 1.0)
	Input.start_joy_vibration(Input.get_connected_joypads()[0], strength * 0.6, strength, 0.12 + strength * 0.25)
