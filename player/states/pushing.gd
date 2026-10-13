extends PlayerState
## Contra un bloque: tras empujar un rato (push_delay del bloque) lo mueve una celda y lo acompaña.
## Si se suelta o se cambia de dirección, vuelve a Idle.

const ANIMATION := &"General/Interact"

var _block: PushBlock
var _direction := Vector3.ZERO
var _held := 0.0


func _enter() -> void:
	_block = blackboard.get_var(BB_PUSH_BLOCK)
	_direction = blackboard.get_var(BB_PUSH_DIR, Vector3.FORWARD)
	_held = 0.0
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.model.look_at(player.model.global_position - _direction, Vector3.UP)
	player.anim_tree.set(&"parameters/Movement/transition_request", "Idle")
	var root := player.anim_tree.tree_root as AnimationNodeBlendTree
	(root.get_node(&"ItemAnim") as AnimationNodeAnimation).animation = ANIMATION
	player.anim_tree.set(&"parameters/UseItem/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _update(delta: float) -> void:
	var input: Vector2 = blackboard.get_var(BB_INPUT_DIR, Vector2.ZERO)
	var wanted := Vector3(input.x, 0.0, input.y)
	if not is_instance_valid(_block) or wanted.length() < 0.3 or wanted.normalized().dot(_direction) < 0.7:
		dispatch("finished")
		return
	if _block.moving:
		player.velocity.x = _direction.x * PushBlock.CELL / _block.move_time
		player.velocity.z = _direction.z * PushBlock.CELL / _block.move_time
	else:
		player.velocity.x = _direction.x * 0.5
		player.velocity.z = _direction.z * 0.5
		_held += delta
		if _held >= _block.push_delay:
			_held = 0.0
			_block.try_push(_direction)
	player.move_and_slide()


func _exit() -> void:
	player.anim_tree.set(&"parameters/UseItem/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
