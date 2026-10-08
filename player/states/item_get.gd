extends PlayerState
## Levanta el ítem de cara a la cámara; a mitad de la animación abre la caja de item get (pausa) y sigue al cerrarla.

const ITEM_GET := preload("res://src/ui/item_get/item_get.tscn")
const ANIMATION := &"General/Use_Item"
## Momento de la animación (0..1) en que el ítem está en alto y se abre la caja.
@export_range(0.0, 1.0) var show_at := 0.45
## Los anillos van por encima de la cabeza, en pantalla.
@export var rings_offset := Vector2(0, -110)

var _duration := 1.0
var _elapsed := 0.0
var _shown := false


func _enter() -> void:
	_elapsed = 0.0
	_shown = false
	player.velocity = Vector3.ZERO
	player.model.look_at(player.model.global_position - Vector3.BACK, Vector3.UP)
	var root := player.anim_tree.tree_root as AnimationNodeBlendTree
	(root.get_node(&"ItemAnim") as AnimationNodeAnimation).animation = ANIMATION
	_duration = player.anim_player.get_animation(ANIMATION).length
	player.anim_tree.set(&"parameters/UseItem/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _update(delta: float) -> void:
	_elapsed += delta
	if not _shown and _elapsed >= show_at * _duration:
		_show()
	if _elapsed >= _duration:
		dispatch("finished")


func _show() -> void:
	_shown = true
	var popup := ITEM_GET.instantiate()
	popup.item = blackboard.get_var("got_item")
	popup.amount = blackboard.get_var("got_amount", 1)
	var camera := player.get_viewport().get_camera_3d()
	if camera:
		popup.anchor = camera.unproject_position(player.global_position + Vector3.UP * 1.8) + rings_offset
	MenuStack.push(popup)
