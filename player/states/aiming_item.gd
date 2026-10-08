extends PlayerState
## Arco y similares: mantener el botón tensa (el player se planta y el stick izquierdo apunta), soltarlo dispara.

const ITEM_ACTIONS: Array[StringName] = [&"item_1", &"item_2"]

## Lo mínimo que hay que mantener antes de que soltar dispare.
@export var min_draw := 0.15
## Cuánto dura el estado después de disparar.
@export var release_time := 0.4
@export var blend_time := 0.12

var _button := 0
var _item: ItemData
var _elapsed := 0.0
var _draw_length := 1.0
var _released_at := -1.0
var _blend: Tween


func _enter() -> void:
	_button = blackboard.get_var("item_button", 0)
	_item = Items.get_item(GameState.item_buttons[_button])
	_elapsed = 0.0
	_released_at = -1.0
	_draw_length = player.anim_player.get_animation(&"CombatRanged/Ranged_Bow_Draw").length
	player.aim.aiming = true
	player.aim.move_aims = true
	player.velocity = Vector3.ZERO
	player.anim_tree.set(&"parameters/Movement/transition_request", "Idle")
	player.equipment.hold(_item)
	player.anim_tree.set(&"parameters/BowPhase/transition_request", "Draw")
	_fade_to(1.0)


func _update(delta: float) -> void:
	_elapsed += delta
	player.move_and_slide()
	if _released_at < 0.0:
		if _elapsed >= _draw_length and player.anim_tree.get(&"parameters/BowPhase/current_state") == "Draw":
			player.anim_tree.set(&"parameters/BowPhase/transition_request", "Idle")
		if _elapsed >= min_draw and not Input.is_action_pressed(ITEM_ACTIONS[_button]):
			_release()
	elif _elapsed - _released_at >= release_time:
		dispatch("finished")


func _exit() -> void:
	player.aim.aiming = false
	player.aim.move_aims = false
	player.equipment.release_held()
	_fade_to(0.0)


func _release() -> void:
	_released_at = _elapsed
	player.anim_tree.set(&"parameters/BowPhase/transition_request", "Release")
	var ctx := player.make_item_context()
	ctx.origin = player.global_position + Vector3.UP * 1.2 + ctx.direction * 0.7
	if GameState.inventory.has(_item.id) and _item.behavior.can_use(ctx, _item):
		_item.behavior.use(ctx, _item)
		Feel.sfx(&"click", player.global_position)
	else:
		player.deny_item(_button)


func _fade_to(amount: float) -> void:
	if _blend:
		_blend.kill()
	_blend = create_tween()
	_blend.tween_property(player.anim_tree, "parameters/BowBlend/blend_amount", amount, blend_time)
