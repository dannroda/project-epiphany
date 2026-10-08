# Autoload
extends Node
## Feedback de combate: hit-stop, sacudida, partículas y sonidos placeholder.

const SFX_BUS := &"SFX"
const MIX_RATE := 22050

var settings: FeelSettings = preload("res://data/feel.tres")
var _sounds: Dictionary[StringName, AudioStreamWAV] = {}


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(SFX_BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, SFX_BUS)
	_sounds = {
		&"hit": _synth(0.09, func(t: float) -> float: return (randf() * 2.0 - 1.0) * 0.6 * exp(-t * 40.0) + sin(TAU * 110.0 * t) * exp(-t * 25.0)),
		&"hurt": _synth(0.16, func(t: float) -> float: return signf(sin(TAU * lerpf(240.0, 110.0, t / 0.16) * t)) * 0.35 * exp(-t * 14.0)),
		&"block": _synth(0.2, func(t: float) -> float: return (sin(TAU * 1400.0 * t) + 0.6 * sin(TAU * 2150.0 * t)) * 0.4 * exp(-t * 22.0)),
		&"click": _synth(0.04, func(t: float) -> float: return sin(TAU * 1800.0 * t) * 0.3 * exp(-t * 90.0)),
		&"roll": _synth(0.25, func(t: float) -> float: return (randf() * 2.0 - 1.0) * 0.25 * sin(PI * t / 0.25)),
		&"deny": _synth(0.18, func(t: float) -> float: return signf(sin(TAU * (140.0 if t < 0.08 else 105.0) * t)) * 0.25 * (1.0 if fmod(t, 0.09) < 0.07 else 0.0)),
		&"heal": _synth(0.45, func(t: float) -> float: return sin(TAU * [523.0, 659.0, 784.0][mini(int(t / 0.15), 2)] * t) * 0.3 * exp(-fmod(t, 0.15) * 12.0)),
	}


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


func shake(amount: float) -> void:
	if not settings.shake_enabled:
		return
	var camera := get_viewport().get_camera_3d()
	if camera and camera.has_method(&"add_trauma"):
		camera.add_trauma(amount)


func sfx(sound: StringName, at: Vector3) -> void:
	var stream: AudioStreamWAV = _sounds.get(sound)
	var scene := get_tree().current_scene
	if stream == null or scene == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = SFX_BUS
	player.volume_db = settings.sfx_volume_db
	player.pitch_scale = 1.0 + randf_range(-settings.pitch_variation, settings.pitch_variation)
	scene.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


## Partículas cortas: &"sparks" (bloqueo) o &"dust" (roll).
func burst(kind: StringName, at: Vector3, direction: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.direction = direction
	var mesh := SphereMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match kind:
		&"sparks":
			particles.amount = 14
			particles.lifetime = 0.25
			particles.spread = 70.0
			particles.initial_velocity_min = 3.0
			particles.initial_velocity_max = 5.0
			particles.gravity = Vector3(0, -6, 0)
			mesh.radius = 0.025
			material.albedo_color = Color(1.0, 0.85, 0.4)
		_:
			particles.amount = 10
			particles.lifetime = 0.45
			particles.spread = 45.0
			particles.initial_velocity_min = 0.8
			particles.initial_velocity_max = 1.6
			particles.gravity = Vector3(0, 0.6, 0)
			particles.scale_amount_min = 0.6
			particles.scale_amount_max = 1.2
			mesh.radius = 0.08
			material.albedo_color = Color(0.75, 0.68, 0.58, 0.7)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.height = mesh.radius * 2.0
	mesh.material = material
	particles.mesh = mesh
	scene.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


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
