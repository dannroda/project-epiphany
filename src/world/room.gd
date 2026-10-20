@tool
class_name Room
extends Area3D
## Sala de mazmorra: la cámara queda adentro de sus límites. El tamaño sale de su CollisionShape3D (una caja)
## o de `camera_limits` si se completa a mano. En el editor dibuja el rectángulo de la sala.

signal player_entered(room: Room)
## Cuando el player pasa a otra sala (los bloques vuelven a su lugar).
signal player_left(room: Room)

const GROUP := &"rooms"
## Lo que solo corre mientras haya algún player en su sala (enemigos, trampas); fuera de toda sala corre siempre.
const SLEEPERS := &"room_sleepers"
## Cerrada, mira si quedan enemigos u oleadas cada tantos frames de física, no en cada uno.
const LOCK_CHECK_TICKS := 6

@export var debug_disble:bool = false

@export var room_index: int = 0 ## Bit en DungeonState.visited_rooms
@export var display_name: String = ""
## Lugar en la grilla de la pantalla de mapa (columna, fila). El mapa se arma leyendo las salas.
@export var map_cell: Vector2i
## Cuántas celdas del mapa ocupa (columnas, filas), desde `map_cell` hacia la derecha y abajo: una sala más grande que
## el paso de la grilla se dibuja entera.
@export var map_size := Vector2i.ONE
## La brújula marca la sala del jefe.
@export var boss_room := false
## Guardar al entrar (la antesala, antes del jefe).
@export var autosave_on_enter := false
## Cuánto se siente el despertar del ojo en esta sala (0 = calma, 1 = clímax): música y ambientación.
@export_range(0.0, 1.0, 0.05) var doom := 0.0
## Opcional, local en XZ: dónde puede estar el FOCO de la cámara. Vacío = lo calcula la cámara para no ver fuera de la sala.
@export var camera_limits: Rect2
## Las persianas se cierran recién cuando terminó de entrar: algo más que el deslizamiento de la cámara
## (TopDownCamera.transition_time).
@export var lock_delay := 0.6
## Lo de la sala despierta este tiempo después de que entra un player: que no lo golpeen apenas cruza.
@export var wake_delay := 0.5
@export_group("Cámara y ambiente")
## Offset de la cámara en esta sala, como el `offset` de la cámara (cero = el del nivel): para una sala más grande o
## más chica que las otras.
@export var camera_offset := Vector3.ZERO
## Campo de visión de la cámara en esta sala (0 = el del nivel).
@export var camera_fov := 0.0
## Cámara, viñeta y luz de la sala (pisa a camera_offset y camera_fov). Uno de data/ambientes/ sirve para todas las
## salas de ese tamaño.
@export var ambiente: AmbientePreset
## Pone el preset en la TopDownCamera y el WorldEnvironment del nivel y deja la cámara encuadrando esta sala (tildar
## Preview en la vista 3D): se ajusta ahí, en sus propias propiedades, y se guarda con el botón de abajo.
@export_tool_button("Editar en la cámara y el entorno", "Camera3D") var _editar_ambiente := editar_ambiente
## Copia lo de la cámara y el entorno al preset (lo guarda en su .tres) y deja el nivel como estaba.
@export_tool_button("Guardar en el preset", "Save") var _guardar_ambiente := guardar_ambiente
@export_tool_button("Cancelar la edición", "Close") var _cancelar_ambiente := cancelar_ambiente


var _outline: MeshInstance3D
var _announced := false
## Persianas cerradas hasta limpiar la sala.
var locked := false
## Hay algún player adentro.
var occupied := false

var _wake_frame := 0
var _checked := false

static var _waking := false
static var _camera: TopDownCamera
static var _camera_frame := -1
static var _outline_material: StandardMaterial3D
## La sala cuyo preset se está editando en el editor y lo que tenían la cámara y el entorno antes.
static var _editing: Room
static var _stash := {}


func _ready() -> void:
	add_to_group(GROUP)
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		_outline = MeshInstance3D.new()
		add_child(_outline, false, INTERNAL_MODE_FRONT)
		return
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	_request_wake()


## `margin`: lo que está en sus paredes también cuenta (las puertas entre dos salas).
func contains(point: Vector3, margin := 0.0) -> bool:
	return distance_to(point) <= margin


## Distancia en planta de `point` a la sala (0 adentro); INF si está en otro piso.
func distance_to(point: Vector3) -> float:
	if DungeonFloor.of(self) and (point.y < floor_y() - DungeonFloor.BELOW or point.y >= floor_y() - DungeonFloor.BELOW + DungeonFloor.HEIGHT):
		return INF
	var area := bounds()
	var flat := Vector2(point.x, point.z)
	return flat.distance_to(flat.clamp(area.position, area.end))


func floor_level() -> int:
	var dungeon_floor := DungeonFloor.of(self)
	return dungeon_floor.level if dungeon_floor else 0


## Altura del piso de la sala: la base de su caja.
func floor_y() -> float:
	var shape := get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if shape == null or not shape.shape is BoxShape3D:
		return global_position.y
	return shape.global_position.y - (shape.shape as BoxShape3D).size.y / 2.0


## La llama la cámara cuando el player entra. Primera visita: se marca en DungeonState y el HUD muestra el nombre.
func mark_entered() -> void:
	var first := not _announced
	if GameState.current_dungeon != &"":
		var dungeon := GameState.current_dungeon_state()
		first = not dungeon.was_visited(room_index)
		dungeon.visit(room_index)
	_announced = true
	if first and not display_name.is_empty():
		Hud.events.area_announced.emit(tr(display_name))
	if debug_disble: return
	player_entered.emit(self)
	if autosave_on_enter:
		SaveManager.autosave.call_deferred()
	if not enemies_inside().is_empty() and not shutters().is_empty():
		create_tween().tween_callback(_lock_after_entering).set_delay(lock_delay)


func enemies_inside() -> Array:
	return get_tree().get_nodes_in_group(Enemy.GROUP).filter(func(enemy: Node) -> bool:
		return not enemy.get(&"is_dead") and contains(enemy.global_position))


func shutters() -> Array:
	return get_tree().get_nodes_in_group(Door.GROUP).filter(func(door: Door) -> bool:
		return door.kind == Door.Kind.SHUTTER and door.room == self)


## Si ya se fueron todos (escalera, pozo, paso atrás) no cierra una sala vacía.
func _lock_after_entering() -> void:
	if not has_player() or enemies_inside().is_empty():
		return
	locked = true
	for door: Door in shutters():
		door.close()


## Oleadas en curso: entre una y otra no queda nadie, pero la sala sigue cerrada.
func waves_running() -> bool:
	return get_tree().get_nodes_in_group(WaveSpawner.GROUP).any(func(spawner: WaveSpawner) -> bool:
		return spawner.room == self and spawner.running)


## También la sala de la cámara: en una puerta el player no está en ninguna, y sigue siendo la sala de la que viene.
func has_player() -> bool:
	if _camera_frame != Engine.get_physics_frames():
		_camera_frame = Engine.get_physics_frames()
		_camera = TopDownCamera.find(get_tree())
	if is_instance_valid(_camera) and _camera.room == self:
		return true
	for player in Players.all:
		if contains(player.global_position):
			return true
	return false


func _request_wake() -> void:
	if not _waking:
		_waking = true
		_wake_rooms.call_deferred()


## Despierta lo de las salas con algún player y duerme lo de las demás (en pausa: sigue donde quedó al volver).
## Estática: si la sala que lo pidió se libera antes (cambio de escena), el pedido igual corre y _waking se limpia.
static func _wake_rooms() -> void:
	_waking = false
	var tree := Engine.get_main_loop() as SceneTree
	var rooms := tree.get_nodes_in_group(GROUP)
	for node in tree.get_nodes_in_group(SLEEPERS):
		var sleeper := node as Node3D
		var awake := Players.all.is_empty()
		var inside := false
		for room: Room in rooms:
			if room.contains(sleeper.global_position):
				inside = true
				awake = awake or (room.has_player() and room._wake_frame == 0)
		awake = awake or not inside
		if not sleeper.has_meta(&"awake_mode"):
			sleeper.set_meta(&"awake_mode", sleeper.process_mode)
		sleeper.process_mode = sleeper.get_meta(&"awake_mode") if awake else Node.PROCESS_MODE_DISABLED


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if has_player() != occupied:
		occupied = not occupied
		if occupied and _checked:
			_wake_frame = Engine.get_physics_frames() + int(wake_delay * Engine.physics_ticks_per_second)
		_request_wake()
	_checked = true
	if _wake_frame and Engine.get_physics_frames() >= _wake_frame:
		_wake_frame = 0
		_request_wake()
	if not locked or Engine.get_physics_frames() % LOCK_CHECK_TICKS != 0:
		return
	if enemies_inside().is_empty() and not waves_running():
		locked = false
		var doors := shutters()
		var open_all := func() -> void:
			for door: Door in doors:
				door.open()
		if doors.is_empty():
			open_all.call()
		else:
			TopDownCamera.reveal_unlock(doors[0], open_all)
		Feel.sfx(&"secret", global_position)


func _process(_delta: float) -> void:
	_draw_outline()
	if _editing == self:
		_frame_editor_camera()


func editar_ambiente() -> void:
	if is_instance_valid(_editing):
		_editing.cancelar_ambiente()
	var camera := _level_camera()
	var world := _level_world()
	if camera == null or world == null:
		push_warning("%s: el nivel necesita una TopDownCamera y un WorldEnvironment" % name)
		return
	if ambiente == null:
		ambiente = AmbientePreset.new()
		ambiente.capture(camera, world)
	_stash = {camera: _read(camera, ["global_transform", "offset", "field_of_view", "fov"])}
	var tone := AmbientePreset.tone_of(world)
	if tone:
		_stash[tone] = _read(tone, AmbientePreset.TONE_PROPERTIES + ["frame_in_editor"])
		tone.frame_in_editor = true
	if world.environment:
		_stash[world.environment] = _read(world.environment, AmbientePreset.LIGHT_PROPERTIES)
	if ambiente.usar_camara:
		camera.set(&"offset", ambiente.offset)
		camera.set(&"field_of_view", ambiente.fov)
	var targets := ambiente.targets(world)
	for target: Object in targets:
		for property: String in targets[target]:
			target.set(property, targets[target][property])
	_editing = self


func guardar_ambiente() -> void:
	if _editing != self or ambiente == null:
		return
	ambiente.capture(_level_camera(), _level_world())
	if ambiente.resource_path != "" and not ambiente.resource_path.contains("::"):
		ResourceSaver.save(ambiente)
	cancelar_ambiente()


func cancelar_ambiente() -> void:
	for target: Object in _stash:
		if is_instance_valid(target):
			for property: String in _stash[target]:
				target.set(property, _stash[target][property])
	_stash.clear()
	_editing = null


func _frame_editor_camera() -> void:
	var camera := _level_camera()
	if camera == null:
		return
	var center := bounds().get_center()
	var focus := Vector3(center.x, floor_y(), center.y)
	var eye_offset: Vector3 = camera.get(&"offset")
	camera.look_at_from_position(focus + eye_offset, focus, Vector3.UP)
	camera.fov = camera.get(&"field_of_view")


func _level_camera() -> Camera3D:
	for camera: Camera3D in _level_root().find_children("*", "Camera3D", true, false):
		if camera.get_script() and camera.get_script().get_global_name() == &"TopDownCamera":
			return camera
	return null


func _level_world() -> WorldEnvironment:
	var found := _level_root().find_children("*", "WorldEnvironment", true, false)
	return found[0] if not found.is_empty() else null


func _level_root() -> Node:
	return owner if owner else get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene


func _read(target: Object, properties: Array) -> Dictionary:
	var out := {}
	for property: String in properties:
		out[property] = target.get(property)
	return out


## Rectángulo global de la sala en XZ (x, z).
func bounds() -> Rect2:
	return BoxBounds.xz(self)


## Dónde puede estar el foco para que la vista (offsets del foco al borde visible, en XZ) no salga de la sala.
func focus_limits(view: Rect2) -> Rect2:
	if camera_limits.has_area():
		return Rect2(camera_limits.position + Vector2(global_position.x, global_position.z), camera_limits.size)
	var room := bounds()
	var min_x := room.position.x - view.position.x
	var max_x := room.end.x - view.end.x
	var min_z := room.position.y - view.position.y
	var max_z := room.end.y - view.end.y
	if min_x > max_x:
		min_x = room.get_center().x - view.get_center().x
		max_x = min_x
	if min_z > max_z:
		min_z = room.get_center().y - view.get_center().y
		max_z = min_z
	return Rect2(min_x, min_z, max_x - min_x, max_z - min_z)


func clamp_focus(point: Vector3, view: Rect2) -> Vector3:
	var limits := focus_limits(view)
	point.x = clampf(point.x, limits.position.x, limits.end.x)
	point.z = clampf(point.z, limits.position.y, limits.end.y)
	return point


func _draw_outline() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var room := bounds()
	var y := 0.1
	var corners := [Vector2(room.position.x, room.position.y), Vector2(room.end.x, room.position.y), room.end, Vector2(room.position.x, room.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		mesh.surface_add_vertex(to_local(Vector3(a.x, global_position.y + y, a.y)))
		mesh.surface_add_vertex(to_local(Vector3(b.x, global_position.y + y, b.y)))
	mesh.surface_end()
	if _outline_material == null:
		_outline_material = StandardMaterial3D.new()
		_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline_material.albedo_color = Color(0.95, 0.75, 0.25)
		_outline_material.no_depth_test = true
	mesh.surface_set_material(0, _outline_material)
	_outline.mesh = mesh


## Las celdas del mapa que ocupa.
func map_rect() -> Rect2i:
	return Rect2i(map_cell, map_size.max(Vector2i.ONE))


## Centro de esas celdas en la grilla del mapa (la celda de una sala de una sola es su `map_cell`).
func map_center() -> Vector2:
	return Vector2(map_cell) + Vector2(map_rect().size - Vector2i.ONE) / 2.0
