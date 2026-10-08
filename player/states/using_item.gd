extends PlayerState
## Usa el ítem del botón X/Y: reproduce su animación y llama a use() en behavior.use_at.

const DEFAULT_ANIMATION := &"General/Use_Item"

var _item: ItemData
var _button := 0
var _duration := 1.0
var _elapsed := 0.0
var _used := false


func _enter() -> void:
	_button = blackboard.get_var("item_button", 0)
	_item = Items.get_item(GameState.item_buttons[_button])
	_elapsed = 0.0
	_used = false
	var tween := create_tween()
	tween.tween_property(player, "velocity", Vector3.ZERO, 0.15)
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
	if not _used and _elapsed >= _item.behavior.use_at * _duration:
		_use()
	if _elapsed >= _duration * _item.behavior.end_at:
		dispatch("finished")


func _exit() -> void:
	if _elapsed < _duration:
		player.anim_tree.set(&"parameters/UseItem/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


func _use() -> void:
	_used = true
	var ctx := player.make_item_context()
	if not GameState.inventory.has(_item.id) or not _item.behavior.can_use(ctx, _item):
		player.deny_item(_button)
		return
	_item.behavior.use(ctx, _item)
	var leaves: ItemData = _item.behavior.get(&"leaves")
	if leaves and not GameState.inventory.has(_item.id) and GameState.item_buttons[_button] == _item.id:
		GameState.assign_button(_button, leaves.id)
