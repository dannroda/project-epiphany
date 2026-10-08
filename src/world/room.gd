@tool
class_name Room
extends Area3D
## Sala de mazmorra: la cámara queda adentro de sus límites. El tamaño sale de su CollisionShape3D (una caja)
## o de `camera_limits` si se completa a mano. En el editor dibuja el rectángulo de la sala.

signal player_entered(room: Room)

const GROUP := &"rooms"

@export var room_index: int = 0 ## Bit en DungeonState.visited_rooms
@export var display_name: String = ""
## Opcional, local en XZ: dónde puede estar el FOCO de la cámara. Vacío = lo calcula la cámara para no ver fuera de la sala.
@export var camera_limits: Rect2

var _outline: MeshInstance3D
var _announced := false
## Persianas cerradas hasta limpiar la sala.
var locked := false


func _ready() -> void:
	add_to_group(GROUP)
	if Engine.is_editor_hint():
		_outline = MeshInstance3D.new()
		add_child(_outline, false, INTERNAL_MODE_FRONT)
		return
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false


func contains(point: Vector3) -> bool:
	return bounds().has_point(Vector2(point.x, point.z))


## La llama la cámara cuando el player entra. Primera visita: se marca en DungeonState y el HUD muestra el nombre.
func mark_entered() -> void:
	var first := not _announced
	if GameState.current_dungeon != &"":
		var dungeon := GameState.current_dungeon_state()
		first = not dungeon.was_visited(room_index)
		dungeon.visit(room_index)
	_announced = true
	if first and not display_name.is_empty():
		get_tree().call_group(&"hud", &"show_area_name", tr(display_name))
	player_entered.emit(self)
	if not enemies_inside().is_empty() and not shutters().is_empty():
		_lock_after_entering.call_deferred()


func enemies_inside() -> Array:
	return get_tree().get_nodes_in_group(&"enemies").filter(func(enemy: Node) -> bool:
		return not enemy.get(&"is_dead") and contains(enemy.global_position))


func shutters() -> Array:
	return get_tree().get_nodes_in_group(&"doors").filter(func(door: Door) -> bool:
		return door.kind == Door.Kind.SHUTTER and door.room == self)


## Se cierran recién cuando el player terminó de entrar (después del deslizamiento de la cámara).
func _lock_after_entering() -> void:
	await get_tree().create_timer(0.6).timeout
	if enemies_inside().is_empty():
		return
	locked = true
	for door: Door in shutters():
		door.close()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not locked:
		return
	if enemies_inside().is_empty():
		locked = false
		for door: Door in shutters():
			door.open()
		Feel.sfx(&"secret", global_position)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
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
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.95, 0.75, 0.25)
	material.no_depth_test = true
	mesh.surface_set_material(0, material)
	_outline.mesh = mesh
