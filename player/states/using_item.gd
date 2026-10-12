extends PlayerState
## Usa el ítem del botón X/Y: reproduce su animación y llama a use() en behavior.use_at.

const DEFAULT_ANIMATION := &"General/Use_Item"
const ITEM_ACTIONS: Array[StringName] = [&"item_1", &"item_2"]

var _item: ItemData
## El ítem del botón: la botella, si _item es su contenido.
var _source: StringName
var _button := 0
var _duration := 1.0
var _elapsed := 0.0
var _used := false
## Con ítems que se pueden mantener (bombas): esperando a ver si suelta (usar) o mantiene (AimingThrow).
var _waiting := false


func _enter() -> void:
	_button = blackboard.get_var("item_button", 0)
	_source = GameState.buttons_of(player.controls.slot)[_button]
	_item = GameState.item_for(_source)
	_elapsed = 0.0
	_used = false
	var tween := create_tween()
	tween.tween_property(player, "velocity", Vector3.ZERO, 0.15)
	_waiting = _item.behavior.get(&"hold_time") != null and player.controls.pressed(ITEM_ACTIONS[_button])
	if not _waiting:
		_start()


func _start() -> void:
	_waiting = false
	_elapsed = 0.0
	var animation := _item.behavior.get_animation(_item)
	if animation == &"" or not player.anim_player.has_animation(animation):
		animation = DEFAULT_ANIMATION
	var root := player.anim_tree.tree_root as AnimationNodeBlendTree
	(root.get_node(&"ItemAnim") as AnimationNodeAnimation).animation = animation
	_duration = player.anim_player.get_animation(animation).length
	player.anim_tree.set(&"parameters/UseItem/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _update(delta: float) -> void:
	_elapsed += delta
	player.move_and_slide()
	if _waiting:
		if not player.controls.pressed(ITEM_ACTIONS[_button]):
			_start()
		elif _elapsed >= _item.behavior.hold_time:
			_waiting = false
			dispatch("aim_throw")
		return
	if not _used and _elapsed >= _item.behavior.use_at * _duration:
		_use()
	if _elapsed >= _duration * _item.behavior.end_at:
		dispatch("finished")


func _exit() -> void:
	if not _waiting and _elapsed < _duration:
		player.anim_tree.set(&"parameters/UseItem/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


func _use() -> void:
	_used = true
	var ctx := player.make_item_context()
	ctx.source = _source
	if not GameState.inventory.has(_source) or not _item.behavior.can_use(ctx, _item):
		player.deny_item(_button)
		return
	_item.behavior.use(ctx, _item)
