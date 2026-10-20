extends PlayerState
## Ítems de apuntar (el arco): mantener el botón tensa y soltarlo dispara; la animación y el giro salen del behavior. Sin objetivo fijado el player se planta y el stick
## izquierdo apunta (OoT); fijado, la flecha va al objetivo y el stick izquierdo camina (strafe).


@export_group("Ajuste")
@export var locked_speed := 5.0
@export_group("")
## Lo mínimo que hay que mantener antes de que soltar dispare.
@export var min_draw := 0.075
## Cuánto dura el estado después de disparar.
@export var release_time := 0.2

var _button := 0
var _item: ItemData
var _inventory: Inventory
var _elapsed := 0.0
var _draw_length := 1.0
var _released_at := -1.0


func _enter() -> void:
	_button = blackboard.get_var(BB_ITEM_BUTTON, 0)
	_item = GameState.item_for(GameState.buttons_of(player.controls.slot)[_button])
	_elapsed = 0.0
	_released_at = -1.0
	_inventory = player.make_item_context().inventory
	var draw := _item.behavior.aim_animation
	_draw_length = player.anim_player.get_animation(draw).length * ANIM_PART if player.anim_player.has_animation(draw) else min_draw
	if player.anim_player.has_animation(draw):
		((player.anim_tree.tree_root as AnimationNodeBlendTree).get_node(&"BowDraw") as AnimationNodeAnimation).animation = draw
	player.aim.aiming = true
	player.aim.yaw_offset = deg_to_rad(_item.behavior.aim_yaw_offset_deg)
	player.velocity = Vector3.ZERO
	player.anim_tree.set(&"parameters/Movement/transition_request", "Idle")
	player.equipment.hold(_item)
	player.anim_tree.set(&"parameters/BowPhase/transition_request", "Draw")
	player.anim_tree.set(&"parameters/Bow/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _update(delta: float) -> void:
	_elapsed += delta
	_move()
	var bow = _bow()
	if bow and _released_at < 0.0:
		bow.nocked = _inventory.has(_item.behavior.ammo.id) if _item.behavior.ammo else true
		bow.draw = _elapsed / _draw_length
	if _released_at < 0.0:
		if _elapsed >= _draw_length and player.anim_tree.get(&"parameters/BowPhase/current_state") == "Draw":
			player.anim_tree.set(&"parameters/BowPhase/transition_request", "Idle")
		if _elapsed >= min_draw and not player.controls.pressed(PlayerCharacter.ITEM_ACTIONS[_button]):
			_release()
	elif _elapsed - _released_at >= release_time:
		dispatch("finished")


func _exit() -> void:
	player.aim.aiming = false
	player.aim.yaw_offset = 0.0
	player.aim.move_aims = false
	player.equipment.release_held()
	player.anim_tree.set(&"parameters/Bow/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


func _release() -> void:
	_released_at = _elapsed
	var bow = _bow()
	if bow:
		bow.draw = 0.0
		bow.nocked = false
	player.anim_tree.set(&"parameters/BowPhase/transition_request", "Release")
	var ctx := player.make_item_context()
	ctx.origin = player.global_position + Vector3.UP * 1.2 + ctx.direction * 0.7
	if ctx.inventory.has(_item.id) and _item.behavior.can_use(ctx, _item):
		_item.behavior.use(ctx, _item)
		Feel.sfx(&"click", player.global_position)
	else:
		player.deny_item(_button)


func _move() -> void:
	var target: Node3D = player.targeting.current
	var locked := target != null and is_instance_valid(target)
	player.aim.move_aims = not locked
	set_locked_legs(locked)
	if locked:
		move_locked(blackboard.get_var(BB_INPUT_DIR, Vector2.ZERO), locked_speed, target, false)
	else:
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		player.move_and_slide()
		player.anim_tree["parameters/Targeting/blend_position"] = Vector2.ZERO


## El modelo en la mano, si se tensa (BowModel).
func _bow() -> Node3D:
	var held := player.equipment.held
	return held if is_instance_valid(held) and &"draw" in held else null
