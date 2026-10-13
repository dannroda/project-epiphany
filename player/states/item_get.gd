extends PlayerState
## Levanta el ítem con las dos manos de cara a la cámara (Carry/ItemGet_Raise → _Hold); arriba hay un destello, suena la
## fanfarria y se abre la caja de item get (pausa). Al cerrarla baja las manos (ItemGet_Lower) y vuelve.

const ITEM_GET := preload("res://src/ui/item_get/item_get.tscn")
const RAISE := &"Carry/ItemGet_Raise"
const LOWER := &"Carry/ItemGet_Lower"
## Pausa con las manos arriba antes de abrir la caja.
@export var beat := 0.12
## Los anillos (con el ítem) van sobre la cabeza, donde se carga lo levantado; corrimiento en pantalla.
@export var rings_offset := Vector2(0, -40)

var _elapsed := 0.0
var _show_at := 0.0
var _shown := false
var _lowered_at := -1.0


func _enter() -> void:
	_elapsed = 0.0
	_shown = false
	_lowered_at = -1.0
	player.velocity = Vector3.ZERO
	player.model.look_at(player.model.global_position - Vector3.BACK, Vector3.UP)
	player.carrier.raise_item()
	_show_at = player.anim_player.get_animation(RAISE).length + beat


func _update(delta: float) -> void:
	_elapsed += delta
	if not _shown and _elapsed >= _show_at:
		_show()
	if _lowered_at >= 0.0 and _elapsed - _lowered_at >= player.anim_player.get_animation(LOWER).length:
		dispatch("finished")


func _exit() -> void:
	player.carrier.drop()


func _show() -> void:
	_shown = true
	var hands := _hands()
	_flash(hands)
	Feel.ui(&"item_get")
	var popup := ITEM_GET.instantiate()
	popup.item = blackboard.get_var(BB_GOT_ITEM)
	popup.amount = blackboard.get_var(BB_GOT_AMOUNT, 1)
	var camera := player.get_viewport().get_camera_3d()
	if camera:
		popup.anchor = camera.unproject_position(player.carrier.socket.global_position) + rings_offset
	popup.closed.connect(_on_closed)
	MenuStack.push(popup)


func _on_closed() -> void:
	player.carrier.lower_item()
	_lowered_at = _elapsed


func _hands() -> Vector3:
	var sockets := [player.equipment.weapon_socket, player.equipment.shield_hand_socket]
	return (sockets[0].global_position + sockets[1].global_position) * 0.5


func _flash(at: Vector3) -> void:
	Feel.burst(&"sparkle", at + Vector3.UP * 0.3, Vector3.UP)
	var light: OmniLight3D = player.get_node(^"%ItemGetLight")
	light.global_position = at + Vector3.UP * 0.4
	light.show()
	var fade := light.create_tween()
	fade.tween_property(light, "light_energy", 0.0, 0.6).from(5.0)
	fade.tween_callback(light.hide)
