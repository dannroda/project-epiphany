extends PlayerState
## Gancho (11.30): el player se planta y dispara hacia donde apunta. Si la punta se clava en un poste o un cofre, vuela
## hasta ahí sin gravedad (cruza agua y huecos); si no, espera a que vuelva.

const ANIMATION := &"General/Use_Item"

@export var pull_speed := 14.0
## A esta distancia del punto donde se clavó, llega.
@export var stop_distance := 0.9
@export var max_pull_time := 1.5

var _hook: Hook
var _direction := Vector3.ZERO
var _pull_time := 0.0
var _landing := Vector3.INF


func _enter() -> void:
	player.attack_runner.stop()
	_pull_time = 0.0
	_landing = Vector3.INF
	var item := player.usable_item(blackboard.get_var(BB_ITEM_BUTTON, 0))
	var behavior := item.behavior as HookBehavior
	var post := player.targeting.current as HookPost
	if post:
		_direction = (post.ring() - player.global_position - Vector3.UP * Hook.HEIGHT).normalized()
	else:
		_direction = player.aim.get_direction() * Vector3(1, 0, 1)
		if _direction.is_zero_approx():
			_direction = player.model.global_basis.z * Vector3(1, 0, 1)
		_direction = _direction.normalized()
	player.model.look_at(player.model.global_position - _direction * Vector3(1, 0, 1), Vector3.UP)
	player.velocity = Vector3.ZERO
	_hook = behavior.hook_scene.instantiate() as Hook
	Spawns.root(player).add_child(_hook)
	_hook.target = post
	_hook.fire(player, _direction, behavior.reach, item.damage)
	Feel.sfx(&"roll", player.global_position)
	if player.anim_player.has_animation(ANIMATION):
		var root := player.anim_tree.tree_root as AnimationNodeBlendTree
		(root.get_node(&"ItemAnim") as AnimationNodeAnimation).animation = ANIMATION
		player.anim_tree.set(&"parameters/UseItem/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _update(delta: float) -> void:
	if not is_instance_valid(_hook) or _hook.phase == Hook.Phase.DONE:
		dispatch("finished")
		return
	if _hook.phase == Hook.Phase.LATCHED:
		_pull(delta)
		return
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.move_and_slide()


func _exit() -> void:
	if is_instance_valid(_hook):
		_hook.release()
	_hook = null


func pulling() -> bool:
	return is_instance_valid(_hook) and _hook.phase == Hook.Phase.LATCHED


func blocks_room_transition() -> bool:
	return pulling()


func _pull(delta: float) -> void:
	_pull_time += delta
	var post := _hook.anchor as HookPost
	if post:
		_pull_to_post(post, delta)
		return
	var to := (_hook.global_position - player.global_position) * Vector3(1, 0, 1)
	if to.length() <= stop_distance or _pull_time >= max_pull_time or _blocked(to.normalized()):
		player.velocity = Vector3.ZERO
		_hook.release()
		dispatch("finished")
		return
	player.velocity = to.normalized() * pull_speed
	player.move_and_slide()


## Vuela derecho hasta el piso del poste, al lado de él, sin chocar en el borde de un desnivel (la punta llegó, así que
## estaba a la vista).
func _pull_to_post(post: HookPost, delta: float) -> void:
	if _landing == Vector3.INF:
		_landing = _landing_by(post)
	player.velocity = Vector3.ZERO
	player.global_position = player.global_position.move_toward(_landing, pull_speed * delta)
	if player.global_position.distance_to(_landing) < 0.01 or _pull_time >= max_pull_time:
		player.global_position = _landing
		_hook.release()
		dispatch("finished")


## Al lado del poste, del lado del player si ahí hay piso (si el poste está al borde, del otro o de costado).
func _landing_by(post: HookPost) -> Vector3:
	var back := (player.global_position - post.global_position) * Vector3(1, 0, 1)
	back = back.normalized() if not back.is_zero_approx() else -_direction * Vector3(1, 0, 1)
	var space := player.get_world_3d().direct_space_state
	for side in [back, back.rotated(Vector3.UP, PI / 2.0), back.rotated(Vector3.UP, -PI / 2.0), -back]:
		var at: Vector3 = post.global_position + side * stop_distance
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN * 0.5)
		ray.exclude = [player.get_rid()]
		var hit := space.intersect_ray(ray)
		if hit and absf(hit.position.y - post.global_position.y) < 0.3:
			return Vector3(at.x, hit.position.y, at.z)
	return post.global_position + back * stop_distance


func _blocked(direction: Vector3) -> bool:
	for i in player.get_slide_collision_count():
		if player.get_slide_collision(i).get_normal().dot(direction) < -0.6:
			return true
	return false
