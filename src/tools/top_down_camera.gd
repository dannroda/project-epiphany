class_name TopDownCamera
extends Camera3D

const GROUP := &"room_camera"
const SKIP_ACTIONS: Array[StringName] = [&"ui_accept", &"attack", &"interact"]

@export var target_node: PlayerCharacter
## FOV 40 y unos 60° de inclinación; una pantalla abarca ≈ 26 × 14.5 m, una sala entera del templo con sus puertas.
@export var offset: Vector3 = Vector3(0, 17.4, 10.0)
## El `fov` de la cámara (lo pisa al arrancar: así se puede poner desde la escena). Lejos y angosta casi no hay perspectiva.
@export var field_of_view := 40.0
## Sin perspectiva (paredes en rampa, estilo Link's Awakening): las paredes se ven del mismo ancho arriba y abajo.
@export var orthographic := false
## Alto en metros de lo que se ve con `orthographic`.
@export var ortho_size := 19.0
@export var smooth_speed: float = 8.0
@export var trauma_decay := 1.6
@export var max_shake_offset := Vector2(0.35, 0.25)
## Metros que empuja el encuadre una sacudida con dirección, por unidad de trauma.
@export var kick_size := 0.5

@export_group("Lock-on")
## 0.5 = punto medio entre player y objetivo.
@export_range(0.0, 1.0) var lock_focus_weight := 0.5
## Cuánto puede alejarse el foco del player, para que no salga de cuadro.
@export var max_lock_offset := 4.0

@export_group("Mirar")
## Metros que el stick derecho corre el foco para estudiar la zona (puzzles); sin objetivo fijado.
@export var look_distance := 5.0
@export var look_speed := 5.0
@export var look_deadzone := 0.2

@export_group("Apuntado")
## Metros que se adelanta el foco hacia donde apunta un ítem a distancia.
@export var aim_look_ahead := 3.0
@export var look_ahead_speed := 4.0

@export_group("Mostrar lo activado")
@export var reveal_pan_time := 0.6
## Viñeta y luz de todos los acercamientos (la cámara del preset no se usa): pisan a las de la sala mientras dura. Un
## AmbienteZoom hijo de lo mostrado (la pelea, la puerta) o de la cámara lo reemplaza.
@export var reveal_look: AmbientePreset = preload("res://data/ambientes/zoom.tres")
## Lo que tarda el ambiente del acercamiento en entrar y en volver al de la sala.
@export var reveal_tone_time := 0.6
## Cuánto se queda mirando después de abrir.
@export var reveal_hold := 0.9
## Se acerca a lo activado: fracción del `offset` normal.
@export_range(0.3, 1.0) var reveal_zoom := 0.6

@export_group("Salas")
## Cuánto tarda el deslizamiento al pasar de una sala a otra.
@export var transition_time := 0.5
## Cuánto entra el player en la sala nueva durante el deslizamiento (lo camina solo).
@export var transition_walk := 1.6
## Alto de las paredes sobre el piso: el borde de arriba de la pantalla llega hasta el tope de la pared norte.
@export var wall_height := 2.6
## Lo de fuera de la sala queda en negro; arranca un poco afuera para no tapar las paredes.
@export var mask_margin := 0.5
## La pared sur de la sala se recorta a esta altura para que no tape la puerta sur.
@export var south_wall_cut := 0.4
## Sin recorte (paredes en rampa, estilo Link's Awakening): la pared sur se ve entera desde arriba.
@export var cuts_south_wall := true
## Metros que la pared sur recortada sigue a la vista más allá del borde de la sala (una pared baja en rampa).
@export var south_wall_reach := 0.0
## Metros de piso más allá del borde sur que entran en el encuadre de una sala fija (la cresta de la pared sur).
@export var south_margin := 0.0

@export_group("Oclusión")
## Si una pared tapa a un player, la cámara gira hasta quedar encima de él en este tiempo (s) y vuelve al salir.
@export var overhead_time := 1.5
## Segundos que sigue encima después de que la pared deja de taparlo: bordeando un risco no sube y baja a cada paso.
@export var overhead_hold := 0.8

@export_group("Co-op")
## Metros que quedan entre el borde de la pantalla y el player más alejado cuando el grupo no se puede abrir más.
@export var leash_margin := 1.5
## Al cruzar uno a otra sala, los demás aparecen a su lado a esta distancia.
@export var follower_spacing := 0.7

const ROOM_MASK := preload("res://src/tools/room_mask.tscn")
const CUTAWAY_MATERIALS: Array[ShaderMaterial] = [
	preload("res://data/kits/materials/wall.tres"),
	preload("res://data/kits/materials/column.tres"),
	preload("res://data/kits/materials/epiphany_stone.tres"),
]
const SOUTH_WALL_DEPTH := 2.0
## El corte arranca un poco dentro de la sala: los ladrillos de la pared sobresalen de la celda.
const SOUTH_WALL_RELIEF := 0.3
## Alturas (sobre los pies) hacia donde se tiran rayos desde la cámara para saber si una pared tapa al player.
const HOLE_PROBES: Array[float] = [0.8, 1.5]
## Un salto de más que esto en un cuadro es un teletransporte (reaparecer, pozo): el borde invisible no lo deshace.
const TELEPORT_DISTANCE := 1.0

var trauma := 0.0
## Lo último que se le pasó a las paredes (pies del player; w, el agujero, queda en 0: la cámara se pone encima).
var player_hole := Vector4.ZERO
## Alguna pared tapa a un player desde el ángulo normal: la cámara está cenital o yendo hacia ahí.
var occluded := false
var _overhead := 0.0
var _overhead_speed := 0.0
var _clear_time := 0.0
var _walls: Dictionary[int, bool] = {}
## Sala actual; null = overworld (seguimiento libre).
var room: Room
var transitioning := false
var revealing := false
var _skippable := false
## Dónde mira la cámara (sin la sacudida); lo usan los tests y el overlay.
var focus := Vector3.ZERO
var _shake_time := 0.0
var _kick := Vector2.ZERO
var _look := Vector3.ZERO
var _look_ahead := Vector3.ZERO
var _mask: Node3D
var _skip := false
var _last_positions: Dictionary[PlayerCharacter, Vector3] = {}
var _player_rids: Array[RID] = []
var _level_offset := Vector3.ZERO
var _level_fov := 0.0
var _room_look_saved := {}


func _ready() -> void:
	fov = field_of_view
	_level_offset = offset
	_level_fov = field_of_view
	if orthographic:
		projection = PROJECTION_ORTHOGONAL
		size = ortho_size
	top_level = true
	if not target_node and get_parent() is PlayerCharacter:
		target_node = get_parent()
	look_at_from_position(global_position, global_position - offset, Vector3.UP)
	add_to_group(GROUP)
	Players.joined.connect(_forget_player_rids)
	Players.left.connect(_forget_player_rids)
	process_physics_priority = 100
	_mask = ROOM_MASK.instantiate()
	add_child(_mask)
	_cut_south_wall(null)


func _forget_player_rids(_player: PlayerCharacter) -> void:
	_player_rids.clear()


## Olvida la sala: la próxima se toma sin transición (al empezar o al reaparecer).
func reset_room() -> void:
	room = null
	transitioning = false
	_mask.hide()
	_cut_south_wall(null)


## Sin deslizarse: al aparecer en otra escena o punto, la cámara arranca sobre el player.
func snap_to_target() -> void:
	_look_ahead = Vector3.ZERO
	_look = Vector3.ZERO
	_last_positions.clear()
	focus = group_center()
	global_position = focus + offset


## Los que encuadra la cámara: los players vivos; si no queda ninguno, el primero.
func framed() -> Array[PlayerCharacter]:
	var living := Players.alive()
	if living.is_empty() and target_node:
		living.append(target_node)
	return living


## Centro (XZ) del rectángulo que encierra a los encuadrados, a la altura del primero.
func group_center(players := framed()) -> Vector3:
	var box := _span_of(players)
	return Vector3(box.get_center().x, target_node.global_position.y, box.get_center().y)


func _span_of(players: Array[PlayerCharacter], extra: Variant = null) -> Rect2:
	var points: Array[Vector3] = []
	for player in players:
		points.append(player.global_position)
	if extra != null:
		points.append(extra)
	var box := Rect2(Vector2(points[0].x, points[0].z), Vector2.ZERO)
	for point in points:
		box = box.expand(Vector2(point.x, point.z))
	return box


## La sala de los players; la actual tiene prioridad mientras estén todos adentro. Si uno pasa a otra sala, la
## cámara va con él y se lleva a los demás (Four Swords).
func _update_room(players: Array[PlayerCharacter]) -> void:
	if room and players.all(func(player: PlayerCharacter) -> bool: return room.contains(player.global_position)):
		return
	for player in players:
		if room and room.contains(player.global_position):
			continue
		for node in get_tree().get_nodes_in_group(Room.GROUP):
			var each := node as Room
			if each.contains(player.global_position):
				enter_room(each, player)
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
	var to_plain := _plain_basis() * global_basis.inverse()
	var origin := to_plain * (project_ray_origin(screen_point) - global_position) + offset
	var ray := to_plain * project_ray_normal(screen_point)
	var t := (height - origin.y) / minf(ray.y, -0.01)
	return Vector2(origin.x + ray.x * t, origin.z + ray.z * t)


## Foco dentro de la sala. Si la sala es más baja que la pantalla, queda fija y centrada en pantalla: con la
## perspectiva el fondo se achica, así que se busca el foco que deja el tope de la pared norte y el piso sur a la
## misma distancia de los bordes.
func _clamp(point: Vector3) -> Vector3:
	var view := view_extents()
	point = room.clamp_focus(point, view)
	var bounds := room.bounds()
	if room.camera_limits.has_area() or bounds.size.y + south_margin >= view.size.y:
		return point
	var floor_y := _floor_y()
	var north := Vector3(bounds.get_center().x, floor_y + wall_height, bounds.position.y)
	var south := Vector3(bounds.get_center().x, floor_y, bounds.end.y + south_margin)
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
	var local := _plain_basis().inverse() * (point - eye)
	return local.y if orthographic else local.y / -local.z


## El encuadre se calcula con la cámara de siempre, aunque esté pasando por arriba del player tapado.
func _plain_basis() -> Basis:
	return Basis.looking_at(-offset, Vector3.FORWARD)


## Tapa todo lo que queda fuera del rectángulo (XZ), desde el piso de abajo hasta el tope de las paredes.
func _mask_around(area: Rect2) -> void:
	const FAR := 300.0
	area = area.grow(mask_margin)
	var floor_y := _floor_y()
	var bottom := floor_y - DungeonFloor.HEIGHT - 2.0
	var top := floor_y + wall_height + 0.02
	var lip := area.end.y - mask_margin + SOUTH_WALL_RELIEF + south_wall_reach if cuts_south_wall else area.end.y
	var south := lip + (top - floor_y) * offset.z / offset.y if cuts_south_wall else lip
	var strips := [
		Rect2(area.position.x - FAR, area.position.y - FAR, area.size.x + FAR * 2.0, FAR),
		Rect2(area.position.x - FAR, south, area.size.x + FAR * 2.0, FAR),
		Rect2(area.position.x - FAR, area.position.y, FAR, maxf(south, area.end.y) - area.position.y),
		Rect2(area.end.x, area.position.y, FAR, maxf(south, area.end.y) - area.position.y),
		Rect2(area.position.x - FAR, lip, area.size.x + FAR * 2.0, south - lip),
		Rect2(area.position.x - FAR, area.end.y - mask_margin, area.size.x + FAR * 2.0, maxf(lip - area.end.y + mask_margin, 0.01)),
	]
	for i in strips.size():
		var strip: Rect2 = strips[i]
		var part := _mask.get_child(i) as MeshInstance3D
		var strip_top := floor_y + 0.05 if i == 4 else floor_y - 0.3 if i == 5 else top
		(part.mesh as BoxMesh).size = Vector3(strip.size.x, strip_top - bottom, strip.size.y)
		part.global_position = Vector3(strip.get_center().x, (strip_top + bottom) / 2.0, strip.get_center().y)
	_mask.show()


## `crosser`: el que entró; los demás aparecen a su lado. Sin él, el primero.
func enter_room(new_room: Room, crosser: PlayerCharacter = null) -> void:
	if new_room == room:
		return
	if crosser == null:
		crosser = target_node
	var previous := room
	room = new_room
	if previous:
		previous.player_left.emit(previous)
	room.mark_entered()
	_cut_south_wall(room)
	DungeonFloor.show_up_to(get_tree(), room.floor_level())
	if previous == null:
		_apply_room_view(room)
		_mask_around(room.bounds())
		focus = _clamp(group_center())
		global_position = focus + offset
		_remember_entry()
		return
	if previous.floor_level() != room.floor_level():
		_apply_room_view(room)
		_change_floor(crosser)
		return
	var step := room.bounds().get_center() - previous.bounds().get_center()
	var direction := Vector3(signf(step.x), 0.0, 0.0) if absf(step.x) > absf(step.y) else Vector3(0.0, 0.0, signf(step.y))
	transitioning = true
	if not room.boss_room:
		GameState.room_entry = crosser.last_ground
	_mask_around(room.bounds().merge(previous.bounds()))
	for player in Players.all:
		player.revive()
	_bring_along(crosser, direction)
	for player in framed():
		player.begin_room_transition(direction, transition_time)
	var from_offset := offset
	var from_fov := fov
	_apply_room_view(room)
	focus = _clamp(crosser.global_position + direction * transition_walk)
	var to_offset := offset
	var to_fov := fov
	offset = from_offset
	fov = from_fov
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", focus + to_offset, transition_time)
	tween.parallel().tween_method(_slide_offset, from_offset, to_offset, transition_time)
	tween.parallel().tween_property(self, "fov", to_fov, transition_time)
	tween.tween_callback(func() -> void:
		transitioning = false
		_mask_around(room.bounds())
		_remember_entry())


func _slide_offset(value: Vector3) -> void:
	offset = value
	global_basis = Basis.looking_at(-_eye(), Vector3.FORWARD)


## Offset y campo de visión de la sala (su AmbientePreset o camera_offset/camera_fov), y la viñeta y la luz del preset
## sobre el WorldEnvironment del nivel; lo que no pone queda como el del nivel.
func _apply_room_view(target: Room) -> void:
	var preset := target.ambiente
	if preset and preset.usar_camara:
		offset = preset.offset
	else:
		offset = target.camera_offset if target.camera_offset != Vector3.ZERO else _level_offset
	if not orthographic:
		if preset and preset.usar_camara:
			fov = preset.fov
		else:
			fov = target.camera_fov if target.camera_fov > 0.0 else _level_fov
	_apply_room_look(preset)


## Pone la viñeta y la luz del preset de la sala, devolviendo antes las de la sala anterior.
func _apply_room_look(preset: AmbientePreset) -> void:
	for target: Object in _room_look_saved:
		for property: String in _room_look_saved[target]:
			target.set(property, _room_look_saved[target][property])
	_room_look_saved.clear()
	if preset == null:
		return
	var targets := preset.targets(_world())
	for target: Object in targets:
		var saved := {}
		for property: String in targets[target]:
			saved[property] = target.get(property)
			target.set(property, targets[target][property])
		_room_look_saved[target] = saved


func _world() -> WorldEnvironment:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var found := scene.find_children("*", "WorldEnvironment", true, false)
	return found[0] if not found.is_empty() else null


## Los demás pasan a la sala nueva junto al que cruzó: a sus costados y, si son más, detrás.
func _bring_along(crosser: PlayerCharacter, direction: Vector3) -> void:
	var side := direction.cross(Vector3.UP)
	var spots: Array[Vector3] = [side, -side, -direction]
	var i := 0
	for player in framed():
		if player == crosser:
			continue
		var spot := spots[mini(i, spots.size() - 1)] * follower_spacing * (1 + i / spots.size())
		player.global_position = crosser.global_position + spot
		player.velocity = Vector3.ZERO
		i += 1
	_last_positions.clear()


func _cut_south_wall(cut_room: Room) -> void:
	var area := Vector4.ZERO
	var height := 0.0
	var lip := 1e6
	if not cuts_south_wall:
		cut_room = null
	if cut_room:
		var bounds := cut_room.bounds().grow(0.05)
		area = Vector4(bounds.position.x - SOUTH_WALL_DEPTH, bounds.end.x + SOUTH_WALL_DEPTH, bounds.end.y - SOUTH_WALL_RELIEF, bounds.end.y + SOUTH_WALL_DEPTH + south_wall_reach)
		height = cut_room.floor_y() + south_wall_cut
		lip = bounds.end.y + SOUTH_WALL_RELIEF + south_wall_reach
	for door: Door in get_tree().get_nodes_in_group(Door.GROUP):
		var inside := cut_room != null and absf(door.global_position.y - cut_room.floor_y()) < 1.0 \
				and door.global_position.z > area.z and door.global_position.z < area.w \
				and door.global_position.x > area.x and door.global_position.x < area.y
		door.south_cut = south_wall_cut if inside else 0.0
	for material in CUTAWAY_MATERIALS:
		material.set_shader_parameter(&"cut_area", area)
		material.set_shader_parameter(&"cut_height", height)
		material.set_shader_parameter(&"cut_lip", lip)


## Si alguna pared tapa a un player desde el ángulo normal, en vez de recortarle un agujero (11.134) la cámara gira
## hasta quedar encima en overhead_time, y vuelve al salir. Las paredes siguen leyendo player_hole, con w en 0.
## Dentro de una sala no: está hecha para verse entera desde su cámara, y sus bordes y muros bajos no cuentan.
func _update_player_hole(delta: float) -> void:
	var hidden := false
	if target_node and room == null:
		for player in framed():
			if _player_hidden(player):
				hidden = true
				break
	_clear_time = 0.0 if hidden else _clear_time + delta
	occluded = hidden or (occluded and _clear_time < overhead_hold)
	_damp_overhead(1.0 if occluded else 0.0, delta)
	var feet := target_node.global_position if target_node else Vector3.ZERO
	player_hole = Vector4(feet.x, feet.y, feet.z, 0.0)
	RenderingServer.global_shader_parameter_set(&"player_hole", player_hole)


## Resorte críticamente amortiguado: arranca y frena sin tirones aunque cambie de idea a mitad de camino.
func _damp_overhead(target: float, delta: float) -> void:
	var omega := 2.5 * 2.0 / maxf(overhead_time, 0.01)
	var x := omega * delta
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := _overhead - target
	var step := (_overhead_speed + omega * change) * delta
	_overhead_speed = (_overhead_speed - omega * step) * decay
	_overhead = clampf(target + (change + step) * decay, 0.0, 1.0)


## El offset de la cámara: el normal, o girado hasta quedar encima del foco mientras algo tapa a un player.
func _eye() -> Vector3:
	return offset.slerp(Vector3.UP * offset.length(), _overhead)


## Solo tapan las paredes: lo que antes se recortaba con el agujero (GridMap y mallas con el shader de pared). Árboles,
## cardones y objetos no: detrás de esos queda la silueta. Se mira desde donde estaría la cámara normal.
func _player_hidden(player: PlayerCharacter) -> bool:
	var space := get_world_3d().direct_space_state
	for height in HOLE_PROBES:
		var point := player.global_position + Vector3.UP * height
		var eye := point + offset if orthographic else focus + offset
		var query := PhysicsRayQueryParameters3D.create(eye, point, 1)
		if _player_rids.is_empty():
			_player_rids.assign(Players.all.map(func(each: PlayerCharacter) -> RID: return each.get_rid()))
		query.exclude = _player_rids
		for attempt in 4:
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				break
			if _is_wall(hit.collider):
				return true
			query.exclude += [hit.rid]
	return false


func _is_wall(collider: Object) -> bool:
	if collider is GridMap:
		return true
	if not collider is StaticBody3D:
		return false
	var id := collider.get_instance_id()
	if not _walls.has(id):
		var body := collider as StaticBody3D
		var meshes := body.find_children("*", "GeometryInstance3D", true, false)
		if body.get_parent() is GeometryInstance3D:
			meshes.append(body.get_parent())
		_walls[id] = meshes.any(_reads_player_hole)
	return _walls[id]


static func _reads_player_hole(geometry: GeometryInstance3D) -> bool:
	var materials: Array[Material] = [geometry.material_override]
	if geometry is MeshInstance3D:
		var mesh_instance := geometry as MeshInstance3D
		for surface in mesh_instance.get_surface_override_material_count():
			materials.append(mesh_instance.get_active_material(surface))
	for material in materials:
		var shader_material := material as ShaderMaterial
		if shader_material and shader_material.shader and shader_material.shader.code.contains("player_hole"):
			return true
	return false


## Donde se reaparece al morir. La sala del jefe no cuenta: se vuelve a la antesala.
## Por un hueco o una escalera: sin deslizarse; los demás van con el que pasó y la entrada se anota al aterrizar.
func _change_floor(crosser: PlayerCharacter) -> void:
	_mask_around(room.bounds())
	for player in Players.all:
		player.revive()
	_bring_along(crosser, Vector3.BACK)
	focus = _clamp(group_center())
	var landing_room := room
	while is_inside_tree() and room == landing_room and not crosser.is_on_floor():
		await get_tree().physics_frame
	if room == landing_room:
		_remember_entry()


func _floor_y() -> float:
	return room.floor_y() if room else target_node.global_position.y


## Solo pisando el suelo de la sala: si cayó a un pozo o al agua mientras entraba, queda el umbral que se anotó al cruzar.
func _remember_entry() -> void:
	if room.boss_room or not target_node.is_on_floor() or not room.contains(target_node.global_position):
		return
	if target_node.global_position.y < room.floor_y() - 0.3:
		return
	GameState.room_entry = target_node.global_position


func _physics_process(delta: float) -> void:
	if not target_node or transitioning or revealing:
		return
	var players := framed()
	var together := players.size() > 1
	if together:
		_hold_together(players)
	_last_positions.clear()
	for player in players:
		_last_positions[player] = player.global_position
	_update_room(players)
	if transitioning:
		return
	var player_position := group_center(players) if together else target_node.global_position
	var desired_offset := Vector3.ZERO
	var locked_target := target_node.targeting.current if target_node.targeting and not together else null
	if locked_target and is_instance_valid(locked_target):
		desired_offset = (locked_target.global_position - player_position) * lock_focus_weight
		desired_offset.y = 0.0
		desired_offset = desired_offset.limit_length(max_lock_offset)

	var desired_look_ahead := Vector3.ZERO
	if target_node.aim and target_node.aim.aiming and not together:
		desired_look_ahead = target_node.aim.get_direction() * aim_look_ahead
	_look_ahead = _look_ahead.lerp(desired_look_ahead, 1.0 - exp(-look_ahead_speed * delta))

	var desired_look := Vector3.ZERO
	var steering_light := target_node.is_blocking() and target_node.shield.is_catching_light()
	if not (locked_target and is_instance_valid(locked_target)) and not steering_light and not together:
		var stick := target_node.controls.look(look_deadzone)
		desired_look = Vector3(stick.x, 0.0, stick.y) * look_distance
	_look = _look.lerp(desired_look, 1.0 - exp(-look_speed * delta))

	focus = player_position + desired_offset + _look_ahead + _look
	if room:
		focus = _clamp(focus)
	var eye := _eye()
	global_position = global_position.lerp(focus + eye, 1.0 - exp(-smooth_speed * delta))
	global_basis = Basis.looking_at(-eye, Vector3.FORWARD)
	if OS.is_debug_build():
		DebugOverlay.watch("camera/focus_offset", (focus - player_position).snappedf(0.01))


## Borde invisible: lo que cada uno se movió desde el cuadro anterior y abre el grupo más de lo que entra en
## pantalla se deshace en ese eje. Los saltos grandes (reaparecer, pozo) no se tocan.
func _hold_together(players: Array[PlayerCharacter]) -> void:
	var fits := view_extents().size - Vector2.ONE * leash_margin * 2.0
	for player in players:
		if not _last_positions.has(player):
			continue
		var before := _last_positions[player]
		var now := player.global_position
		if now.distance_to(before) > TELEPORT_DISTANCE:
			continue
		var others := players.filter(func(other: PlayerCharacter) -> bool: return other != player)
		var span_before := _span_of(others, before).size
		var span_now := _span_of(others, now).size
		if span_now.x > fits.x and span_now.x > span_before.x:
			now.x = before.x
			player.velocity.x = 0.0
		if span_now.y > fits.y and span_now.y > span_before.y:
			now.z = before.z
			player.velocity.z = 0.0
		player.global_position = now


## Los tests la apagan (el runner, antes de cada test) salvo los que prueban el acercamiento.
static var unlock_reveals := true
## Cuadros que se queda mirando después de que termina de abrirse.
const REVEAL_TAIL_FRAMES := 4

## Lo que se destraba por una acción (switches, puzzle, horda) se muestra con `reveal`.
static func reveal_unlock(target: Node3D, action: Callable) -> void:
	if unlock_reveals:
		reveal(target, action)
	else:
		action.call()


## Pausa, lleva la cámara a `target`, corre `action` (abrir la puerta…), espera (`hold`, o `reveal_hold` si es
## negativo) y vuelve al player. Si no hay cámara, el juego ya está en pausa o `target` está en una sala sin player
## (oculta), solo corre `action`. `skippable`: se
## corta con SKIP_ACTIONS (la presentación de un jefe que ya viste).
static func reveal(target: Node3D, action: Callable, hold := -1.0, skippable := false) -> void:
	var camera := target.get_tree().get_first_node_in_group(GROUP) as TopDownCamera
	if camera == null or camera.revealing or camera.transitioning or target.get_tree().paused or SaveManager.loading \
			or not _in_a_player_room(target):
		action.call()
		return
	camera._skippable = skippable
	await camera._reveal(target, action, hold)
	camera._skippable = false


## Las salas que no tienen player están ocultas: lo que se abre en otra sala no se muestra.
static func _in_a_player_room(target: Node3D) -> bool:
	var rooms := target.get_tree().get_nodes_in_group(Room.GROUP).filter(func(room: Room) -> bool:
		return room.contains(target.global_position, 1.0))
	return rooms.is_empty() or rooms.any(func(room: Room) -> bool: return room.has_player())


## Corta lo que queda del acercamiento en curso (la intro del jefe se puede saltar).
func skip_reveal() -> void:
	if revealing:
		_skip = true


func _unhandled_input(event: InputEvent) -> void:
	if not revealing or not _skippable:
		return
	for action in SKIP_ACTIONS:
		if event.is_action_pressed(action):
			skip_reveal()
			get_viewport().set_input_as_handled()
			return


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set(&"player_hole", Vector4.ZERO)
	if revealing:
		revealing = false
		get_tree().paused = false


## Foco del acercamiento: el objetivo (o su `reveal_point()`, si lo tiene), a la altura del player.
func reveal_focus(target: Node3D) -> Vector3:
	var point: Vector3 = target.call(&"reveal_point") if target.has_method(&"reveal_point") else target.global_position
	point.y = target_node.global_position.y
	return point


func _reveal(target: Node3D, action: Callable, hold: float) -> void:
	var tree := get_tree()
	var target_mode := target.process_mode
	revealing = true
	_skip = false
	process_mode = PROCESS_MODE_ALWAYS
	target.process_mode = PROCESS_MODE_ALWAYS
	tree.paused = true
	var back := global_position
	var zoom: float = target.call(&"reveal_zoom", reveal_zoom) if target.has_method(&"reveal_zoom") else reveal_zoom
	var look := _reveal_preset(target)
	var mood := look.targets(_world()) if look else {}
	var mood_back := {}
	for holder: Object in mood:
		mood_back[holder] = {}
		for property: String in mood[holder]:
			mood_back[holder][property] = holder.get(property)
	_tween_mood(mood)
	await _pan(reveal_focus(target) + _eye() * zoom)
	if not is_inside_tree():
		for holder: Object in mood_back:
			for property: String in mood_back[holder]:
				holder.set(property, mood_back[holder][property])
		return
	var left := 0.0
	if is_instance_valid(target):
		action.call()
		left = _reveal_time(target, hold)
	while left > 0.0 and not _skip and is_inside_tree():
		await tree.process_frame
		left -= get_process_delta_time()
	for i in REVEAL_TAIL_FRAMES:
		if _skip:
			break
		await tree.process_frame
	_tween_mood(mood_back)
	await _pan(back)
	if is_instance_valid(target):
		target.process_mode = target_mode
	process_mode = PROCESS_MODE_INHERIT
	tree.paused = false
	revealing = false


func _reveal_preset(target: Node) -> AmbientePreset:
	for node: Node in [target, self]:
		for child in node.get_children():
			if child is AmbienteZoom and child.preset:
				return child.preset
	return reveal_look


## Lleva cada objeto (TonoLA, Environment) a sus valores {propiedad: valor}.
func _tween_mood(values: Dictionary) -> void:
	if values.is_empty():
		return
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for holder: Object in values:
		for property: String in values[holder]:
			tween.tween_property(holder, NodePath(property), values[holder][property], reveal_tone_time)


## Lo que tarda en abrirse lo mostrado (puerta, reja, puente); sin animación conocida, `reveal_hold`.
func _reveal_time(target: Node3D, hold: float) -> float:
	if hold >= 0.0:
		return hold
	for property: StringName in [&"open_time", &"duration"]:
		if property in target:
			return target.get(property)
	return reveal_hold


func _pan(to: Vector3) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", to, reveal_pan_time)
	while tween.is_running() and not _skip and is_inside_tree():
		await get_tree().process_frame
	tween.kill()
	if is_inside_tree():
		global_position = to


## Sacudida por trauma: suma, decae sola y mueve solo el encuadre (h/v offset), no la cámara.
## Con `direction` (XZ del mundo) además empuja el encuadre hacia ese lado y vuelve.
func add_trauma(amount: float, direction := Vector3.ZERO) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)
	if not direction.is_zero_approx():
		var flat := Vector2(direction.x, -direction.z).normalized()
		_kick += flat * kick_size * amount


func _process(delta: float) -> void:
	_update_player_hole(delta)
	_kick = _kick.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))
	if trauma <= 0.0:
		h_offset = _kick.x
		v_offset = _kick.y
		return
	trauma = maxf(trauma - trauma_decay * delta, 0.0)
	var shake := trauma * trauma
	_shake_time += delta * 30.0
	h_offset = max_shake_offset.x * shake * sin(_shake_time * 1.7) + _kick.x
	v_offset = max_shake_offset.y * shake * sin(_shake_time * 2.3) + _kick.y
