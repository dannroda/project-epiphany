class_name TopDownCamera
extends Camera3D

@export var target_node: PlayerCharacter
## Como el remake de Link's Awakening: FOV 40 y unos 60° de inclinación; una pantalla abarca ≈ 20 × 10.5 m.
@export var offset: Vector3 = Vector3(0, 13.4, 7.7)
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
## Alto de las paredes sobre el piso: el borde de arriba de la pantalla llega hasta el tope de la pared norte.
@export var wall_height := 2.6
## Lo de fuera de la sala queda en negro; arranca un poco afuera para no tapar las paredes.
@export var mask_margin := 0.5

var trauma := 0.0
## Sala actual; null = overworld (seguimiento libre).
var room: Room
var transitioning := false
## Dónde mira la cámara (sin la sacudida); lo usan los tests y el overlay.
var focus := Vector3.ZERO
var _shake_time := 0.0
var _look_ahead := Vector3.ZERO
var _mask: Node3D


func _init() -> void:
	fov = 40.0


func _ready() -> void:
	top_level = true
	if not target_node and get_parent() is PlayerCharacter:
		target_node = get_parent()
	look_at_from_position(global_position, global_position - offset, Vector3.UP)
	add_to_group(&"room_camera")
	_build_mask()


## Olvida la sala: la próxima se toma sin transición (al empezar o al reaparecer).
func reset_room() -> void:
	room = null
	transitioning = false
	_mask.hide()


## Sin deslizarse: al aparecer en otra escena o punto, la cámara arranca sobre el player.
func snap_to_target() -> void:
	_look_ahead = Vector3.ZERO
	focus = target_node.global_position
	global_position = focus + offset


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


## Lo que abarca la pantalla alrededor del foco, en XZ (offsets desde el foco), como en un Zelda 2D: el ancho es el
## de la fila del player, abajo llega hasta el piso y arriba hasta el tope de las paredes. Lo que sobra queda en negro.
func view_extents() -> Rect2:
	var screen := get_viewport().get_visible_rect().size
	var left := _offset_at_height(Vector2(0.0, screen.y / 2.0), 0.0)
	var right := _offset_at_height(Vector2(screen.x, screen.y / 2.0), 0.0)
	var top := _offset_at_height(Vector2(screen.x / 2.0, 0.0), wall_height)
	var bottom := _offset_at_height(Vector2(screen.x / 2.0, screen.y), 0.0)
	return Rect2(left.x, top.y, right.x - left.x, bottom.y - top.y)


func _offset_at_height(screen_point: Vector2, height: float) -> Vector2:
	var ray := project_ray_normal(screen_point)
	var t := (height - offset.y) / minf(ray.y, -0.01)
	return Vector2(offset.x + ray.x * t, offset.z + ray.z * t)


## Foco dentro de la sala. Si la sala es más baja que la pantalla, queda fija y centrada en pantalla: con la
## perspectiva el fondo se achica, así que se busca el foco que deja el tope de la pared norte y el piso sur a la
## misma distancia de los bordes.
func _clamp(point: Vector3) -> Vector3:
	var view := view_extents()
	point = room.clamp_focus(point, view)
	var bounds := room.bounds()
	if room.camera_limits.has_area() or bounds.size.y >= view.size.y:
		return point
	var floor_y := target_node.global_position.y
	var north := Vector3(bounds.get_center().x, floor_y + wall_height, bounds.position.y)
	var south := Vector3(bounds.get_center().x, floor_y, bounds.end.y)
	var low := bounds.position.y - view.size.y
	var high := bounds.end.y + view.size.y
	for i in 24:
		var middle := (low + high) / 2.0
		var eye := Vector3(point.x, floor_y, middle) + offset
		if _screen_height(north, eye) + _screen_height(south, eye) > 0.0:
			high = middle
		else:
			low = middle
	point.z = (low + high) / 2.0
	return point


## Altura en pantalla (tangente, + = arriba) de un punto visto desde `eye` con la orientación de la cámara.
func _screen_height(point: Vector3, eye: Vector3) -> float:
	var local := global_basis.inverse() * (point - eye)
	return local.y / -local.z


func _build_mask() -> void:
	_mask = Node3D.new()
	_mask.name = "RoomMask"
	_mask.top_level = true
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.BLACK
	for i in 4:
		var part := MeshInstance3D.new()
		part.mesh = BoxMesh.new()
		part.material_override = material
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mask.add_child(part)
	_mask.hide()
	add_child(_mask)


## Tapa todo lo que queda fuera del rectángulo (XZ), desde abajo del piso hasta el tope de las paredes.
func _mask_around(area: Rect2) -> void:
	const FAR := 300.0
	area = area.grow(mask_margin)
	var floor_y := target_node.global_position.y
	var bottom := floor_y - 2.0
	var top := floor_y + wall_height + 0.02
	var strips := [
		Rect2(area.position.x - FAR, area.position.y - FAR, area.size.x + FAR * 2.0, FAR),
		Rect2(area.position.x - FAR, area.end.y, area.size.x + FAR * 2.0, FAR),
		Rect2(area.position.x - FAR, area.position.y, FAR, area.size.y),
		Rect2(area.end.x, area.position.y, FAR, area.size.y),
	]
	for i in 4:
		var strip: Rect2 = strips[i]
		var part := _mask.get_child(i) as MeshInstance3D
		(part.mesh as BoxMesh).size = Vector3(strip.size.x, top - bottom, strip.size.y)
		part.global_position = Vector3(strip.get_center().x, (top + bottom) / 2.0, strip.get_center().y)
	_mask.show()


func enter_room(new_room: Room) -> void:
	if new_room == room:
		return
	var previous := room
	room = new_room
	if previous:
		previous.player_left.emit(previous)
	room.mark_entered()
	if previous == null:
		_mask_around(room.bounds())
		focus = _clamp(target_node.global_position)
		global_position = focus + offset
		GameState.room_entry = target_node.global_position
		return
	var step := room.bounds().get_center() - previous.bounds().get_center()
	var direction := Vector3(signf(step.x), 0.0, 0.0) if absf(step.x) > absf(step.y) else Vector3(0.0, 0.0, signf(step.y))
	transitioning = true
	_mask_around(room.bounds().merge(previous.bounds()))
	target_node.begin_room_transition(direction, transition_time)
	focus = _clamp(target_node.global_position + direction * transition_walk)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", focus + offset, transition_time)
	tween.tween_callback(func() -> void:
		transitioning = false
		_mask_around(room.bounds())
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
		focus = _clamp(focus)
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
