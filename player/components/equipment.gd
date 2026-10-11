class_name Equipment
extends Node
## Pone en las manos el modelo de lo que GameState tiene equipado.

signal weapon_changed(item: ItemData)

@export var weapon_socket: Node3D
@export var shield_hand_socket: Node3D
@export var shield_back_socket: Node3D
## Donde va lo que se sostiene al usarlo (el arco), en la mano del escudo.
@export var held_socket: Node3D

var weapon: ItemData
## El destello del player: los modelos que se ponen en las manos lo llevan también.
var flash: HitFlash:
	set(value):
		flash = value
		for socket in [weapon_socket, shield_hand_socket, shield_back_socket]:
			if socket:
				flash.cover(socket)
var shield_in_hand: Node3D
var shield_on_back: Node3D
## Ítem a distancia que se sostiene mientras se usa (el arco), en la mano del escudo.
var held: Node3D


func _ready() -> void:
	GameState.equipment_changed.connect(refresh.unbind(2))
	GameState.loaded.connect(refresh)
	refresh()


func refresh() -> void:
	weapon = _equipped(ItemData.Category.SWORD)
	_place(weapon_socket, weapon)
	var shield := _equipped(ItemData.Category.SHIELD)
	var hand_visible := shield_in_hand.visible if shield_in_hand else false
	shield_in_hand = _place(shield_hand_socket, shield)
	shield_on_back = _place(shield_back_socket, shield)
	if shield_in_hand:
		show_shield_in_hand(hand_visible)
	_dress(_equipped(ItemData.Category.ARMOR))
	weapon_changed.emit(weapon)


func hold(item: ItemData) -> void:
	release_held()
	if item.equip_scene == null:
		return
	held = item.equip_scene.instantiate() as Node3D
	if held is EquippedItem:
		held.item = item
	(held_socket if held_socket else shield_hand_socket).add_child(held)
	if flash:
		flash.cover(held)
	weapon_socket.visible = false
	show_shield_in_hand(false)


## El escudo está en la mano o en la espalda; el que no se ve tampoco colisiona.
func show_shield_in_hand(in_hand: bool) -> void:
	if shield_in_hand == null:
		return
	_set_present(shield_in_hand, in_hand)
	_set_present(shield_on_back, not in_hand)


func _dress(armor: ItemData) -> void:
	var visuals := owner.get_node_or_null(^"ModelController/Visuals")
	if visuals == null:
		return
	for mesh: MeshInstance3D in visuals.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = armor.body_material if armor else null


func _set_present(model: Node3D, present: bool) -> void:
	model.visible = present
	for shape in model.find_children("*", "CollisionShape3D", true, false):
		shape.set_deferred(&"disabled", not present)


func release_held() -> void:
	if is_instance_valid(held):
		held.queue_free()
	held = null
	weapon_socket.visible = true


func damage_reduction() -> float:
	var armor := _equipped(ItemData.Category.ARMOR)
	return armor.damage_reduction if armor else 0.0


func _equipped(category: ItemData.Category) -> ItemData:
	var id: StringName = GameState.equipment.get(category, &"")
	return Items.get_item(id) if id != &"" else null


func _place(socket: Node3D, item: ItemData) -> Node3D:
	for child in socket.get_children():
		socket.remove_child(child)
		child.queue_free()
	if item == null or item.equip_scene == null:
		return null
	var model := item.equip_scene.instantiate() as Node3D
	if model is EquippedItem:
		model.item = item
	socket.add_child(model)
	if flash:
		flash.cover(model)
	return model
