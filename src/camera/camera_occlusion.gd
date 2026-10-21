class_name CameraOcclusion
extends Node
## Si alguna pared tapa a un player desde el ángulo normal, en vez de recortarle un agujero (11.134) la cámara gira
## hasta quedar encima en overhead_time, y vuelve al salir. Las paredes siguen leyendo player_hole, con w en 0.
## Dentro de una sala no: está hecha para verse entera desde su cámara, y sus bordes y muros bajos no cuentan.

## Alturas (sobre los pies) hacia donde se tiran rayos desde la cámara para saber si una pared tapa al player.
const HOLE_PROBES: Array[float] = [0.8, 1.5]

@export var camera: TopDownCamera
@export var overhead_time := 1.5
## Segundos que sigue encima después de que la pared deja de taparlo: bordeando un risco no sube y baja a cada paso.
@export var overhead_hold := 0.8

## Lo último que se le pasó a las paredes (pies del player; w, el agujero, queda en 0: la cámara se pone encima).
var player_hole := Vector4.ZERO
## Alguna pared tapa a un player desde el ángulo normal: la cámara está cenital o yendo hacia ahí.
var occluded := false
## 0 en el ángulo normal, 1 encima del foco.
var overhead := 0.0
var _overhead_speed := 0.0
var _clear_time := 0.0
var _walls: Dictionary[int, bool] = {}
var _player_rids: Array[RID] = []
var _ray := PhysicsRayQueryParameters3D.new()
var _hit := PhysicsIntersectRayResult3D.new()


func _ready() -> void:
	Players.joined.connect(_forget_player_rids)
	Players.left.connect(_forget_player_rids)


func _forget_player_rids(_player: PlayerCharacter) -> void:
	_player_rids.clear()


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set(&"player_hole", Vector4.ZERO)


func _process(delta: float) -> void:
	var hidden := false
	if camera.target_node and camera.room == null:
		for player in camera.framed():
			if _player_hidden(player):
				hidden = true
				break
	_clear_time = 0.0 if hidden else _clear_time + delta
	occluded = hidden or (occluded and _clear_time < overhead_hold)
	_damp(1.0 if occluded else 0.0, delta)
	var feet := camera.target_node.global_position if camera.target_node else Vector3.ZERO
	player_hole = Vector4(feet.x, feet.y, feet.z, 0.0)
	RenderingServer.global_shader_parameter_set(&"player_hole", player_hole)


## Resorte críticamente amortiguado: arranca y frena sin tirones aunque cambie de idea a mitad de camino.
func _damp(target: float, delta: float) -> void:
	var omega := 2.5 * 2.0 / maxf(overhead_time, 0.01)
	var x := omega * delta
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := overhead - target
	var step := (_overhead_speed + omega * change) * delta
	_overhead_speed = (_overhead_speed - omega * step) * decay
	overhead = clampf(target + (change + step) * decay, 0.0, 1.0)


## Solo tapan las paredes: lo que antes se recortaba con el agujero (GridMap y mallas con el shader de pared). Árboles,
## cardones y objetos no: detrás de esos queda la silueta. Se mira desde donde estaría la cámara normal.
func _player_hidden(player: PlayerCharacter) -> bool:
	var space := camera.get_world_3d().direct_space_state
	for height in HOLE_PROBES:
		var point := player.global_position + Vector3.UP * height
		var eye := point + camera.offset if camera.orthographic else camera.focus + camera.offset
		_ray.from = eye
		_ray.to = point
		_ray.collision_mask = 1
		if _player_rids.is_empty():
			_player_rids.assign(Players.all.map(func(each: PlayerCharacter) -> RID: return each.get_rid()))
		_ray.exclude = _player_rids
		for attempt in 4:
			if not space.intersect_ray_into(_ray, _hit):
				break
			if _is_wall(_hit.collider):
				return true
			_ray.exclude += [_hit.collider_rid]
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
