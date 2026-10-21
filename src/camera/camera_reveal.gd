class_name CameraReveal
extends Node
## El acercamiento de la cámara a lo que se activó: pausa, va hasta ahí, corre la acción (abrir la puerta…), espera y
## vuelve al player. Se entra por `TopDownCamera.reveal`.

const SKIP_ACTIONS: Array[StringName] = [&"ui_accept", &"attack", &"interact"]
## Cuadros que se queda mirando después de que termina de abrirse.
const TAIL_FRAMES := 4

@export var camera: TopDownCamera
@export var pan_time := 0.6
## Viñeta y luz de todos los acercamientos (la cámara del preset no se usa): pisan a las de la sala mientras dura. Un
## AmbienceZoom hijo de lo mostrado (la pelea, la puerta) o de la cámara lo reemplaza.
@export var look: AmbiencePreset = preload("res://data/ambiences/zoom.tres")
## Lo que tarda el ambiente del acercamiento en entrar y en volver al de la sala.
@export var tone_time := 0.6
## Cuánto se queda mirando después de abrir.
@export var hold := 0.9
## Se acerca a lo activado: fracción del `offset` normal.
@export_range(0.3, 1.0) var zoom := 0.6

var revealing := false
## Se corta con SKIP_ACTIONS (la presentación de un jefe que ya viste).
var skippable := false
var _skip := false


## Corta lo que queda del acercamiento en curso.
func skip() -> void:
	if revealing:
		_skip = true


func _unhandled_input(event: InputEvent) -> void:
	if not revealing or not skippable:
		return
	for action in SKIP_ACTIONS:
		if event.is_action_pressed(action):
			skip()
			get_viewport().set_input_as_handled()
			return


func _exit_tree() -> void:
	if revealing:
		revealing = false
		Pause.release(&"reveal")


## Foco del acercamiento: el objetivo (o su `reveal_point()`, si lo tiene), a la altura del player.
func focus_of(target: Node3D) -> Vector3:
	var point: Vector3 = target.call(&"reveal_point") if target.has_method(&"reveal_point") else target.global_position
	point.y = camera.target_node.global_position.y
	return point


## `hold` negativo: lo que tarda en abrirse lo mostrado.
func run(target: Node3D, action: Callable, hold_time: float) -> void:
	var tree := get_tree()
	var target_mode := target.process_mode
	revealing = true
	_skip = false
	camera.process_mode = PROCESS_MODE_ALWAYS
	target.process_mode = PROCESS_MODE_ALWAYS
	Pause.hold(&"reveal")
	var back := camera.global_position
	var target_zoom: float = target.call(&"reveal_zoom", zoom) if target.has_method(&"reveal_zoom") else zoom
	var preset := _preset_for(target)
	camera.tween_look_to(preset.targets(camera.world()) if preset else {}, tone_time)
	await _pan(focus_of(target) + camera.eye() * target_zoom)
	if not is_inside_tree():
		return
	var left := 0.0
	if is_instance_valid(target):
		action.call()
		left = _time_for(target, hold_time)
	while left > 0.0 and not _skip and is_inside_tree():
		await tree.process_frame
		left -= get_process_delta_time()
	for i in TAIL_FRAMES:
		if _skip:
			break
		await tree.process_frame
	camera.fade_look(tone_time)
	await _pan(back)
	if is_instance_valid(target):
		target.process_mode = target_mode
	camera.process_mode = PROCESS_MODE_INHERIT
	Pause.release(&"reveal")
	revealing = false


func _preset_for(target: Node) -> AmbiencePreset:
	for node: Node in [target, camera]:
		for child in node.get_children():
			if child is AmbienceZoom and child.preset:
				return child.preset
	return look


## Lo que tarda en abrirse lo mostrado (puerta, reja, puente); sin animación conocida, `hold`.
func _time_for(target: Node3D, hold_time: float) -> float:
	if hold_time >= 0.0:
		return hold_time
	for property: StringName in [&"open_time", &"duration"]:
		if property in target:
			return target.get(property)
	return hold


func _pan(to: Vector3) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, ^"global_position", to, pan_time)
	while tween.is_running() and not _skip and is_inside_tree():
		await get_tree().process_frame
	tween.kill()
	if is_inside_tree():
		camera.global_position = to
