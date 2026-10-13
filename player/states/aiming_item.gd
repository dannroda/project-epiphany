extends PlayerState
## Arco y similares: mantener el botón tensa y soltarlo dispara. Sin objetivo fijado el player se planta y el stick
## izquierdo apunta (OoT); fijado, la flecha va al objetivo y el stick izquierdo camina (strafe).

const LOCKED_SPEED := 2.5

## Lo mínimo que hay que mantener antes de que soltar dispare.
@export var min_draw := 0.15
## Cuánto dura el estado después de disparar.
@export var release_time := 0.4
@export var blend_time := 0.12
## La animación de KayKit tensa el arco 62° a la izquierda del frente del modelo: se compensa para que la flecha salga hacia la mira.
@export var bow_yaw_offset_deg := 62.0

var _button := 0
var _item: ItemData
var _elapsed := 0.0
var _draw_length := 1.0
var _released_at := -1.0
var _blend: Tween


func _enter() -> void:
	_button = blackboard.get_var(BB_ITEM_BUTTON, 0)
	_item = GameState.item_for(GameState.buttons_of(player.controls.slot)[_button])
	_elapsed = 0.0
	_released_at = -1.0
	_draw_length = player.anim_player.get_animation(&"CombatRanged/Ranged_Bow_Draw").length
	player.aim.aiming = true
	player.aim.yaw_offset = deg_to_rad(bow_yaw_offset_deg)
	player.velocity = Vector3.ZERO
	player.anim_tree.set(&"parameters/Movement/transition_request", "Idle")
	player.equipment.hold(_item)
	player.anim_tree.set(&"parameters/BowPhase/transition_request", "Draw")
	_fade_to(1.0)


func _update(delta: float) -> void:
	_elapsed += delta
	_move()
	var bow = _bow()
	if bow and _released_at < 0.0:
		bow.nocked = GameState.inventory.has(_item.behavior.ammo.id) if _item.behavior.ammo else true
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
	_fade_to(0.0)


func _release() -> void:
	_released_at = _elapsed
	var bow = _bow()
	if bow:
		bow.draw = 0.0
		bow.nocked = false
	player.anim_tree.set(&"parameters/BowPhase/transition_request", "Release")
	var ctx := player.make_item_context()
	ctx.origin = player.global_position + Vector3.UP * 1.2 + ctx.direction * 0.7
	if GameState.inventory.has(_item.id) and _item.behavior.can_use(ctx, _item):
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
		move_locked(blackboard.get_var(BB_INPUT_DIR, Vector2.ZERO), LOCKED_SPEED, target, false)
	else:
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		player.move_and_slide()
		player.anim_tree["parameters/Targeting/blend_position"] = Vector2.ZERO


func _fade_to(amount: float) -> void:
	if _blend:
		_blend.kill()
	_blend = create_tween()
	_blend.tween_property(player.anim_tree, "parameters/BowBlend/blend_amount", amount, blend_time)


## El modelo en la mano, si se tensa (BowModel).
func _bow() -> Node3D:
	var held := player.equipment.held
	return held if is_instance_valid(held) and &"draw" in held else null
