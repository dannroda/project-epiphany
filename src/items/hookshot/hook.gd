class_name Hook
extends Node3D
## La punta del gancho (11.30). Sale recta hasta `reach`: en un HookPost o un cofre se clava (el estado Hooking lleva al
## player hasta ahí), trae lo liviano (vasijas, rocas, recolectables; la vasija grande, de a una celda), golpea con
## `hook` lo que tiene Hurtbox (saca la coraza, baja el escudo, aturde) y contra lo demás rebota y vuelve.

enum Phase { OUT, LATCHED, BACK, DRAG, DONE }

const ELEMENT := &"hook"
## Altura de la punta sobre los pies del player.
const HEIGHT := 0.9
const LINK := 0.16

@export var speed := 26.0
@export var return_speed := 32.0
@export var radius := 0.3
@export var stun_time := 1.2

@onready var head: Node3D = $Head
@onready var chain: MultiMeshInstance3D = $Chain

var phase := Phase.OUT
var user: PlayerCharacter
## Donde se clavó.
var anchor: Node3D
## El poste fijado: va derecho a él y no se engancha en otra cosa (para fijarlo tenía que estar a la vista).
var target: HookPost
var _direction := Vector3.ZERO
var _reach := 8.0
var _travelled := 0.0
var _damage := 1
var _carried: Node3D
var _block: PushBlock


func _ready() -> void:
	for i in chain.multimesh.instance_count:
		chain.multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(0, 0, -LINK * i)))
	chain.multimesh.visible_instance_count = 0


func fire(by: PlayerCharacter, direction: Vector3, reach: float, damage: int) -> void:
	user = by
	_direction = direction
	_reach = reach
	_damage = damage
	global_position = hand()
	head.global_basis = _facing(_direction)
	_draw_chain()


## Donde nace la cadena: delante del player, a la altura de la punta.
func hand() -> Vector3:
	return user.global_position + Vector3.UP * HEIGHT + _direction * 0.3


## El player llegó (o se cortó): la punta desaparece.
func release() -> void:
	phase = Phase.DONE
	queue_free()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(user):
		release()
		return
	match phase:
		Phase.OUT:
			_fly(delta)
		Phase.BACK:
			_come_back(delta)
		Phase.DRAG:
			_drag()
	_draw_chain()


func _fly(delta: float) -> void:
	var step := minf(speed * delta, _reach - _travelled)
	var from := global_position
	var to := from + _direction * step
	for hit in _probe(from, to):
		if _react(hit[0], hit[1]):
			return
	global_position = to
	_travelled += step
	if _travelled >= _reach - 0.001 or (target and _travelled > hand().distance_to(target.ring()) + 1.0):
		phase = Phase.BACK


## Lo que toca en este paso: primero el rayo (paredes), después una esfera en la punta (lo que pasa cerca de la línea).
func _probe(from: Vector3, to: Vector3) -> Array:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [user.get_rid(), user.hurtbox.get_rid()]
	var found := []
	var ray := PhysicsRayQueryParameters3D.create(from, to)
	ray.collide_with_areas = true
	ray.exclude = exclude
	var hit := space.intersect_ray(ray)
	if hit:
		found.append([hit.collider, hit.position])
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, to)
	query.collide_with_areas = true
	query.exclude = exclude
	for touch in space.intersect_shape(query, 16):
		found.append([touch.collider, to])
	return found


## true si la punta se queda con esto (se clava, lo trae, lo golpea o rebota); false si lo atraviesa.
func _react(collider: Object, point: Vector3) -> bool:
	var node := collider as Node
	if node == null or node == user or user.is_ancestor_of(node):
		return false
	if target and node != target and not target.is_ancestor_of(node):
		return false
	if node.is_in_group(&"walk_guard"):
		return false
	anchor = _anchor_of(node)
	if anchor:
		global_position = point - _direction * 0.1
		phase = Phase.LATCHED
		Feel.sfx(&"hit_stone", point)
		Feel.burst(&"sparks", point, -_direction)
		return true
	var block := _ancestor_of_type(node, PushBlock) as PushBlock
	if block is BigPot:
		_block = block
		phase = Phase.DRAG
		Feel.sfx(&"click", point)
		return true
	if node is Pickup:
		_carried = node
		phase = Phase.BACK
		return true
	var liftable := _liftable_of(node)
	if liftable:
		_carried = liftable.target
		phase = Phase.BACK
		Feel.sfx(&"click", point)
		return true
	if not node is Hurtbox and node.get(&"hurtbox") is Hurtbox:
		node = node.get(&"hurtbox")
	if node is Hurtbox:
		if (node as Hurtbox).team == user.hurtbox.team and (node as Hurtbox).team != EntityConfig.Team.NEUTRAL:
			return false
		var info := DamageInfo.make(_damage, 0.0, user, ELEMENT)
		info.team = user.hurtbox.team
		info.stun_time = stun_time
		(node as Hurtbox).receive(info)
		phase = Phase.BACK
		return true
	if node is Area3D:
		return false
	Feel.sfx(&"block", point)
	Feel.burst(&"sparks", point, -_direction)
	phase = Phase.BACK
	return true


func _anchor_of(node: Node) -> Node3D:
	var post := _ancestor_of_type(node, HookPost)
	return post if post else _ancestor_of_type(node, Chest)


func _ancestor_of_type(node: Node, type: Variant) -> Node:
	for i in 3:
		if node == null:
			return null
		if is_instance_of(node, type):
			return node
		node = node.get_parent()
	return null


func _liftable_of(node: Node) -> Liftable:
	if node is Liftable:
		return node
	for owner_node: Node in [node.get_parent(), node.get_parent().get_parent() if node.get_parent() else null]:
		if owner_node == null:
			continue
		for child in owner_node.get_children():
			if child is Liftable:
				return child
	return null


func _come_back(delta: float) -> void:
	var to := hand() - global_position
	var step := return_speed * delta
	if to.length() <= maxf(step, 0.6):
		_arrive()
		return
	global_position += to.normalized() * step
	if is_instance_valid(_carried):
		_carried.global_position = Vector3(global_position.x, _carried.global_position.y, global_position.z)


func _arrive() -> void:
	if is_instance_valid(_carried):
		var feet := user.global_position + _direction * 0.9
		_carried.global_position = Vector3(feet.x, _carried.global_position.y, feet.z)
		if _carried is Breakable:
			(_carried as Breakable).smash(user.global_position)
	release()


## La vasija grande viene de a una celda, empujada hacia el player, hasta quedar al lado o trabarse.
func _drag() -> void:
	if not is_instance_valid(_block):
		phase = Phase.BACK
		return
	global_position = _block.global_position + Vector3.UP * HEIGHT
	if _block.moving:
		return
	var toward := (user.global_position - _block.global_position) * Vector3(1, 0, 1)
	if toward.length() < PushBlock.CELL * 1.3 or not _block.try_push(PushBlock.axis(toward)):
		phase = Phase.BACK


func _draw_chain() -> void:
	var from := hand()
	var to := global_position
	var length := from.distance_to(to)
	chain.visible = length > 0.05
	if not chain.visible:
		return
	chain.global_transform = Transform3D(_facing(to - from), from)
	chain.multimesh.visible_instance_count = mini(ceili(length / LINK), chain.multimesh.instance_count)


func _facing(direction: Vector3) -> Basis:
	return Basis.looking_at(direction, Vector3.UP if absf(direction.normalized().y) < 0.99 else Vector3.BACK)
