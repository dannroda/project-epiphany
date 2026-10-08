class_name Equipment
extends Node
## Pone en las manos el modelo de lo que GameState tiene equipado.

signal weapon_changed(item: ItemData)

@export var weapon_socket: Node3D
@export var shield_hand_socket: Node3D
@export var shield_back_socket: Node3D

var weapon: ItemData
var shield_in_hand: Node3D
var shield_on_back: Node3D


func _ready() -> void:
	GameState.equipment_changed.connect(func(_category: ItemData.Category, _id: StringName) -> void: refresh())
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
		shield_in_hand.visible = hand_visible
		shield_on_back.visible = not hand_visible
	weapon_changed.emit(weapon)


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
	return model
