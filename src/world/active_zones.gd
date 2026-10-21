class_name ActiveZones
extends Node
## El overworld activo por zonas (15.13): las zonas a `reach` de algún player despiertan; en las demás los enemigos
## duermen (process_mode desactivado: sin física, IA ni animación). Las hojas del paisaje van por chunks más chicos que
## las zonas y dejan de caer lejos.

## Distancia en XZ de un player al borde de una zona para que despierte; más que lo que muestra la cámara.
@export var reach := 22.0
## Donde están las partículas del paisaje.
@export var scenery: Node
## Lado de los chunks de las partículas del paisaje.
@export var chunk_size := 16.0

var _zones: Array[Rect2] = []
var _awake: Array[bool] = []
var _leaves: Dictionary[Vector2i, Array] = {}
var _lit: Dictionary[Vector2i, bool] = {}
var _asleep: Dictionary[Node, bool] = {}


func _ready() -> void:
	_collect.call_deferred()


func _collect() -> void:
	if not is_inside_tree():
		return
	for zone: AreaZone in get_tree().get_nodes_in_group(AreaZone.GROUP):
		_zones.append(zone.bounds())
		_awake.append(true)
	if scenery == null:
		return
	for particles: GPUParticles3D in scenery.find_children("*", "GPUParticles3D", true, false):
		if particles.emitting and not particles.one_shot:
			var chunk := Vector2i((Vector2(particles.global_position.x, particles.global_position.z) / chunk_size).floor())
			if not _leaves.has(chunk):
				_leaves[chunk] = []
				_lit[chunk] = true
			_leaves[chunk].append(particles)


func _physics_process(_delta: float) -> void:
	var players := Players.all.filter(func(player: PlayerCharacter) -> bool: return player.is_inside_tree())
	for zone in _zones.size():
		_awake[zone] = players.is_empty() or _near(_zones[zone].grow(reach), players)
	for chunk in _leaves:
		var lit := players.is_empty() or _near(Rect2(Vector2(chunk) * chunk_size, Vector2.ONE * chunk_size).grow(reach), players)
		if lit != _lit[chunk]:
			_lit[chunk] = lit
			_emit(_leaves[chunk], lit)
	for enemy in get_tree().get_nodes_in_group(Enemy.GROUP):
		if enemy is Node3D:
			_wake(enemy, players.is_empty() or _awake_at((enemy as Node3D).global_position, players))


func _awake_at(point: Vector3, players: Array) -> bool:
	var zone := _zone_of(point)
	if zone >= 0:
		return _awake[zone]
	return _near(Rect2(point.x, point.z, 0.0, 0.0).grow(reach), players)


func _zone_of(point: Vector3) -> int:
	for zone in _zones.size():
		if _zones[zone].has_point(Vector2(point.x, point.z)):
			return zone
	return -1


func _near(area: Rect2, players: Array) -> bool:
	for player: PlayerCharacter in players:
		if area.has_point(Vector2(player.global_position.x, player.global_position.z)):
			return true
	return false


func _emit(leaves: Array, on: bool) -> void:
	for i in leaves.size():
		if is_instance_valid(leaves[i]):
			(leaves[i] as GPUParticles3D).emitting = on


func _wake(enemy: Node, awake: bool) -> void:
	if awake:
		if _asleep.erase(enemy) and enemy.process_mode == PROCESS_MODE_DISABLED:
			enemy.process_mode = PROCESS_MODE_INHERIT
	elif enemy.process_mode == PROCESS_MODE_INHERIT and not _asleep.has(enemy):
		_asleep[enemy] = true
		enemy.process_mode = PROCESS_MODE_DISABLED
