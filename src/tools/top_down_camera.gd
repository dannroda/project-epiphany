class_name TopDownCamera
extends Camera3D

@export var target_node: PlayerCharacter
@export var offset: Vector3 = Vector3(0, 12, 7) # Altura (Y=12) y distancia hacia atrás (Z=7)
@export var smooth_speed: float = 8.0
@export var trauma_decay := 1.6
@export var max_shake_offset := Vector2(0.35, 0.25)

@export_group("Lock-on")
## 0.5 = punto medio entre player y objetivo.
@export_range(0.0, 1.0) var lock_focus_weight := 0.5
## Cuánto puede alejarse el foco del player, para que no salga de cuadro.
@export var max_lock_offset := 4.0

@export_group("Apuntado")
## Metros que se adelanta el foco hacia donde apunta un ítem a distancia.
@export var aim_look_ahead := 3.0
@export var look_ahead_speed := 4.0

@export_group("Salas")
## Cuánto tarda el deslizamiento al pasar de una sala a otra.
@export var transition_time := 0.5
## Cuánto entra el player en la sala nueva durante el deslizamiento (lo camina solo).
@export var transition_walk := 1.6

var trauma := 0.0
## Sala actual; null = overworld (seguimiento libre).
var room: Room
var transitioning := false
## Dónde mira la cámara (sin la sacudida); lo usan los tests y el overlay.
var focus := Vector3.ZERO
var _shake_time := 0.0
var _look_ahead := Vector3.ZERO


func _ready() -> void:
	top_level = true
	if not target_node and get_parent() is PlayerCharacter:
		target_node = get_parent()
	look_at_from_position(global_position, global_position - offset, Vector3.UP)
	add_to_group(&"room_camera")


## Olvida la sala: la próxima se toma sin transición (al empezar o al reaparecer).
func reset_room() -> void:
	room = null
	transitioning = false


## La sala que contiene el centro del player; la actual tiene prioridad mientras siga adentro.
func _update_room() -> void:
	var at := target_node.global_position
	if room and room.contains(at):
		return
	for node in get_tree().get_nodes_in_group(Room.GROUP):
		var each := node as Room
		if each.contains(at):
			enter_room(each)
			return


## Suelo visible alrededor del foco, en XZ (offsets desde el foco). El ancho sale de las esquinas de abajo
## (la parte cercana y angosta del trapecio) y el fondo, del centro de los bordes de arriba y abajo: así el player
## nunca queda fuera de cuadro; solo pueden asomar las esquinas lejanas de arriba, detrás de las paredes.
func view_extents() -> Rect2:
	var screen := get_viewport().get_visible_rect().size
	var bottom_left := _ground_offset(Vector2(0.0, screen.y))
	var bottom_right := _ground_offset(screen)
	var top := _ground_offset(Vector2(screen.x / 2.0, 0.0))
	var bottom := _ground_offset(Vector2(screen.x / 2.0, screen.y))
	var low := Vector2(bottom_left.x, top.y)
	var high := Vector2(bottom_right.x, bottom.y)
	return Rect2(low, high - low)


func _ground_offset(screen_point: Vector2) -> Vector2:
	var ray := project_ray_normal(screen_point)
	var t := -offset.y / minf(ray.y, -0.01)
	return Vector2(offset.x + ray.x * t, offset.z + ray.z * t)


func enter_room(new_room: Room) -> void:
	if new_room == room:
		return
	var previous := room
	room = new_room
	room.mark_entered()
	if previous == null:
		focus = room.clamp_focus(target_node.global_position, view_extents())
		global_position = focus + offset
		GameState.room_entry = target_node.global_position
		return
	var step := room.bounds().get_center() - previous.bounds().get_center()
	var direction := Vector3(signf(step.x), 0.0, 0.0) if absf(step.x) > absf(step.y) else Vector3(0.0, 0.0, signf(step.y))
	transitioning = true
	target_node.begin_room_transition(direction, transition_time)
	focus = room.clamp_focus(target_node.global_position + direction * transition_walk, view_extents())
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", focus + offset, transition_time)
	tween.tween_callback(func() -> void:
		transitioning = false
		GameState.room_entry = target_node.global_position)


func _physics_process(delta: float) -> void:
	if not target_node or transitioning:
		return
	_update_room()
	if transitioning:
		return
	var player_position := target_node.global_position
	var desired_offset := Vector3.ZERO
	var locked_target := target_node.targeting.current if target_node.targeting else null
	if locked_target and is_instance_valid(locked_target):
		desired_offset = (locked_target.global_position - player_position) * lock_focus_weight
		desired_offset.y = 0.0
		desired_offset = desired_offset.limit_length(max_lock_offset)

	var desired_look_ahead := Vector3.ZERO
	if target_node.aim and target_node.aim.aiming:
		desired_look_ahead = target_node.aim.get_direction() * aim_look_ahead
	_look_ahead = _look_ahead.lerp(desired_look_ahead, 1.0 - exp(-look_ahead_speed * delta))

	focus = player_position + desired_offset + _look_ahead
	if room:
		focus = room.clamp_focus(focus, view_extents())
	global_position = global_position.lerp(focus + offset, 1.0 - exp(-smooth_speed * delta))
	DebugOverlay.watch("camera/focus_offset", (focus - player_position).snappedf(0.01))


## Sacudida por trauma: suma, decae sola y mueve solo el encuadre (h/v offset), no la cámara.
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if trauma <= 0.0:
		h_offset = 0.0
		v_offset = 0.0
		return
	trauma = maxf(trauma - trauma_decay * delta, 0.0)
	var shake := trauma * trauma
	_shake_time += delta * 30.0
	h_offset = max_shake_offset.x * shake * sin(_shake_time * 1.7)
	v_offset = max_shake_offset.y * shake * sin(_shake_time * 2.3)
