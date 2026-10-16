class_name GroundWaves
extends Node3D
## Ondas de choque por el piso de un pisotón: una chica en cada pisada (cuando un pie baja) y una grande cuando la
## `punta` (la cabeza de la maza) toca el piso. Le pegan a todo lo que esté en el piso adentro del anillo (players y
## otros enemigos), menos al que las larga (`emitter`, por defecto el padre del modelo). Las mallas son los hijos.

const HURTBOX_LAYER := 16

@export var skeleton: Skeleton3D
@export var punta: Node3D
@export var feet: Array[StringName] = [&"foot.l", &"foot.r"]
## Alturas sobre el piso (del pie): sube de `lift` para armarse y larga la onda al bajar de `land`.
@export var lift := 0.5
@export var land := 0.38
@export var slam_lift := 1.5
@export var slam_land := 0.5
@export_group("Pisada")
@export var step_radius := 3.0
@export var step_damage := 1
@export var step_knockback := 6.0
@export_group("Golpe")
@export var slam_radius := 6.5
@export var slam_damage := 2
@export var slam_knockback := 12.0
@export_group("Onda")
@export var speed := 9.0
@export var width := 0.9
@export var glow := Color(0.95, 0.25, 0.08)
@export var core := Color(1.0, 0.8, 0.4)

var emitter: Node3D
## Vacío: le pega a todos (el Centinela golpea a sus huancas). La Momia solo a los players.
var only_teams: Array[EntityConfig.Team] = []
var team: EntityConfig.Team = EntityConfig.Team.NEUTRAL
var _armed := {}
var _rings: Array[Dictionary] = []
var _query := PhysicsShapeQueryParameters3D.new()
var _shape := CylinderShape3D.new()
var _hits := PhysicsIntersectShapeResult3D.new()


func _ready() -> void:
	emitter = owner.get_parent() as Node3D if owner and owner.get_parent() is Node3D else owner as Node3D
	_query.shape = _shape
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	_query.collision_mask = HURTBOX_LAYER
	for mesh: MeshInstance3D in _meshes():
		mesh.hide()


func _physics_process(delta: float) -> void:
	var ground := global_position.y
	if skeleton:
		for foot in feet:
			var bone := skeleton.find_bone(foot)
			if bone >= 0:
				_track(foot, (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin, ground, lift, land, false)
	if punta:
		_track(&"punta", punta.global_position, ground, slam_lift, slam_land, true)
	_spread(delta)


func _track(key: StringName, at: Vector3, ground: float, up: float, down: float, slam: bool) -> void:
	var height := at.y - ground
	if height > up:
		_armed[key] = true
	elif height < down and _armed.get(key, false):
		_armed[key] = false
		emit(Vector3(at.x, ground, at.z), slam)


## Larga una onda desde `at` (en el piso): la grande del golpe o la de una pisada.
func emit(at: Vector3, slam := false) -> void:
	if slam:
		pulse(at, slam_radius, slam_damage, slam_knockback, true)
	else:
		pulse(at, step_radius, step_damage, step_knockback)
	Feel.shake(0.3 if slam else 0.08)
	Feel.burst(&"dust", at + Vector3.UP * 0.2, Vector3.UP)


## Una onda con su alcance y su daño. Sin malla libre reusa la primera.
func pulse(at: Vector3, radius: float, damage: int, knockback: float, big := false) -> void:
	var meshes := _meshes()
	if meshes.is_empty():
		return
	var free := meshes.filter(func(mesh: MeshInstance3D) -> bool: return not mesh.visible)
	var mesh: MeshInstance3D = free[0] if not free.is_empty() else meshes[0]
	_rings = _rings.filter(func(ring: Dictionary) -> bool: return ring.mesh != mesh)
	mesh.global_position = at + Vector3.UP * 0.05
	mesh.scale = Vector3.ONE * 0.01
	mesh.set_instance_shader_parameter(&"width", width)
	mesh.set_instance_shader_parameter(&"glow", glow)
	mesh.set_instance_shader_parameter(&"core", core)
	mesh.show()
	_rings.append({mesh = mesh, at = 0.0, center = at, hit = [], slam = big, radius = radius, damage = damage,
		knockback = knockback})


func stop() -> void:
	_rings.clear()
	for mesh in _meshes():
		mesh.hide()


func _spread(delta: float) -> void:
	for ring in _rings.duplicate():
		ring.at += speed * delta
		if ring.at > ring.radius:
			ring.mesh.hide()
			_rings.erase(ring)
			continue
		ring.mesh.scale = Vector3(ring.at, 1.0 if ring.slam else 0.6, ring.at)
		ring.mesh.set_instance_shader_parameter(&"radius", ring.at)
		ring.mesh.set_instance_shader_parameter(&"fade", 1.0 - ring.at / ring.radius)
		for hurtbox in _hurtboxes_near(ring.center, ring.at + width):
			if ring.hit.has(hurtbox) or _is_emitter(hurtbox) or not hurtbox.is_grounded() \
					or (not only_teams.is_empty() and not hurtbox.team in only_teams):
				continue
			var away: Vector3 = (hurtbox.global_position - ring.center) * Vector3(1, 0, 1)
			if absf(away.length() - ring.at) > width / 2.0:
				continue
			ring.hit.append(hurtbox)
			var info := DamageInfo.make(ring.damage, ring.knockback, emitter if emitter else self, DamageInfo.BLAST)
			info.team = team
			hurtbox.receive(info)


func _hurtboxes_near(center: Vector3, radius: float) -> Array[Hurtbox]:
	_shape.radius = radius
	_shape.height = 4.0
	_query.transform = Transform3D(Basis.IDENTITY, center + Vector3.UP * 1.5)
	var found: Array[Hurtbox] = []
	_hits.max_intersections = 32
	get_world_3d().direct_space_state.intersect_shape_into(_query, _hits)
	for i in _hits.get_intersection_count():
		if _hits.get_collider(i) is Hurtbox:
			found.append(_hits.get_collider(i))
	return found


func _is_emitter(hurtbox: Hurtbox) -> bool:
	return emitter != null and (hurtbox == emitter or emitter.is_ancestor_of(hurtbox))


func _meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	meshes.assign(get_children().filter(func(child: Node) -> bool: return child is MeshInstance3D))
	return meshes
