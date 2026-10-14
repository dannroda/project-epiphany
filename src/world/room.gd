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

@export var room_index: int = 0 ## Bit en DungeonState.visited_rooms
@export var display_name: String = ""
## Lugar en la grilla de la pantalla de mapa (columna, fila). El mapa se arma leyendo las salas.
@export var map_cell: Vector2i
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

var _outline: MeshInstance3D
var _announced := false
## Persianas cerradas hasta limpiar la sala.
var locked := false
## Hay algún player adentro.
var occupied := false

var _wake_frame := 0
var _checked := false

static var _waking := false
static var _outline_material: StandardMaterial3D


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


func contains(point: Vector3) -> bool:
	if DungeonFloor.of(self) and (point.y < floor_y() - DungeonFloor.BELOW or point.y >= floor_y() - DungeonFloor.BELOW + DungeonFloor.HEIGHT):
		return false
	return bounds().has_point(Vector2(point.x, point.z))


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
		get_tree().call_group(Hud.GROUP, &"show_area_name", tr(display_name))
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


func has_player() -> bool:
	return Players.all.any(func(player: PlayerCharacter) -> bool: return contains(player.global_position))


func _request_wake() -> void:
	if not _waking:
		_waking = true
		_wake_rooms.call_deferred()


## Despierta lo de las salas con algún player y duerme lo de las demás (en pausa: sigue donde quedó al volver).
func _wake_rooms() -> void:
	_waking = false
	if not is_inside_tree():
		return
	var rooms := get_tree().get_nodes_in_group(GROUP)
	for node in get_tree().get_nodes_in_group(SLEEPERS):
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
	if not locked:
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


## Rectángulo global de la sala en XZ (x, z).
func bounds() -> Rect2:
	var shape := get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if shape == null or not shape.shape is BoxShape3D:
		return Rect2(Vector2(global_position.x, global_position.z), Vector2.ZERO)
	var size := (shape.shape as BoxShape3D).size
	var center := shape.global_position
	return Rect2(center.x - size.x / 2.0, center.z - size.z / 2.0, size.x, size.z)


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
