class_name ItemRing
extends Control
## Anillo de ítems de un player (13.9, mockups Coop_Ring y Solo_Ring): mientras mantiene `item_ring` (LB, F) elige con
## el stick y lo pone en X o Y. El que lleva otro player se ve apagado con su etiqueta. Jugando solo el mundo casi se
## detiene; en co-op no se pausa nada.

signal opened
signal closed

const SLOT := preload("res://src/ui/hud/ring_slot.tscn")

@export var radius := 98.0
@export var solo_time_scale := 0.05
@export var pick_deadzone := 0.5
@export var taken_alpha := 0.45

@onready var rim: Panel = %Rim
@onready var slots: Control = %Slots
@onready var tag: PanelContainer = %Tag
@onready var title: Label = %Title
@onready var detail: Label = %Detail
@onready var hint_x: TextureRect = %HintX
@onready var hint_y: TextureRect = %HintY

var player: PlayerCharacter
var _colors: Array[Color] = []
var _items: Array[ItemData] = []
var _selected := 0
var _slowed := false
## Si otro (una cutscene) ya tenía los controles al abrir: al cerrar se los deja.
var _was_captured := false


func _ready() -> void:
	GameState.item_buttons_changed.connect(_refresh)
	GameState.inventory.changed.connect(_on_inventory_changed)


func bind(who: PlayerCharacter, colors: Array[Color], coop: bool) -> void:
	player = who
	_colors = colors
	rim.self_modulate = _color_of(who.controls.slot)
	tag.visible = coop
	tag.self_modulate = rim.self_modulate
	(tag.get_node(^"Label") as Label).text = "P%d" % (who.controls.slot + 1)


func is_open() -> bool:
	return visible


func _exit_tree() -> void:
	if visible:
		_close()


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var held := Input.is_action_pressed(player.controls.action(&"item_ring")) and _can_open()
	if held and not visible:
		_open()
	elif not held and visible:
		_close()
	elif visible:
		_pick()


func _input(event: InputEvent) -> void:
	if not visible or not is_instance_valid(player):
		return
	for i in PlayerCharacter.ITEM_ACTIONS.size():
		if event.is_action_pressed(player.controls.action(PlayerCharacter.ITEM_ACTIONS[i])):
			get_viewport().set_input_as_handled()
			_assign(i)


## Abierto, sigue mientras se mantenga; cerrado, no se abre si otro sistema (una cutscene) tiene los controles.
func _can_open() -> bool:
	return not MenuStack.is_open() and not player.is_dead and player.can_interact() \
			and not Players.uses_shared_item_menu() and (visible or not player.controls.captured)


func _open() -> void:
	_items.assign(Items.database.items.filter(func(item: ItemData) -> bool:
		return item.category == ItemData.Category.USABLE and not item.bottled and GameState.inventory.has(item.id)))
	if _items.is_empty():
		return
	_build_slots()
	var current := GameState.buttons_of(player.controls.slot)[0]
	_selected = maxi(_items.find(Items.get_item(current)) if current != &"" else 0, 0)
	_was_captured = player.controls.captured
	player.controls.captured = true
	visible = true
	if Players.all.size() == 1 and Engine.time_scale >= 1.0:
		Engine.time_scale = solo_time_scale
		_slowed = true
	_refresh()
	opened.emit()


func _close() -> void:
	visible = false
	if is_instance_valid(player):
		player.controls.captured = _was_captured
	if _slowed:
		Engine.time_scale = 1.0
		_slowed = false
	closed.emit()


func _build_slots() -> void:
	for child in slots.get_children():
		slots.remove_child(child)
		child.queue_free()
	var center := size / 2.0
	for i in _items.size():
		var angle := TAU * i / _items.size()
		var slot: Control = SLOT.instantiate()
		slots.add_child(slot)
		slot.position = center + Vector2(sin(angle), -cos(angle)) * radius - slot.custom_minimum_size / 2.0
		(slot.get_node(^"Icon") as TextureRect).texture = GameState.item_for(_items[i].id).icon


func _pick() -> void:
	var c := player.controls
	var stick := Input.get_vector(c.action(&"move_left"), c.action(&"move_right"), c.action(&"move_forward"), c.action(&"move_backward"))
	if stick.length() < pick_deadzone:
		return
	var index := posmod(roundi(atan2(stick.x, -stick.y) / (TAU / _items.size())), _items.size())
	if index != _selected:
		_selected = index
		_refresh()


func _assign(button: int) -> void:
	if _items.is_empty():
		return
	if not GameState.assign_button(button, _items[_selected].id, player.controls.slot):
		player.deny_item(button)


func _refresh() -> void:
	if not visible or not is_instance_valid(player):
		return
	var mine := player.controls.slot
	var buttons := GameState.buttons_of(mine)
	for i in _items.size():
		var slot := slots.get_child(i) as Control
		var item := _items[i]
		var owner_slot := GameState.owner_of(item.id)
		var taken := owner_slot not in [-1, mine]
		(slot.get_node(^"Icon") as TextureRect).modulate.a = taken_alpha if taken else 1.0
		var selected := slot.get_node(^"Selected") as Panel
		selected.visible = i == _selected
		selected.self_modulate = rim.self_modulate
		var badge := slot.get_node(^"Badge") as TextureRect
		var button := buttons.find(item.id)
		badge.visible = button != -1
		if badge.visible:
			badge.texture = InputPrompts.icon_for(PlayerCharacter.ITEM_ACTIONS[button], player)
		var owner_tag := slot.get_node(^"Owner") as PanelContainer
		owner_tag.visible = taken
		if taken:
			owner_tag.self_modulate = _color_of(owner_slot)
			(owner_tag.get_node(^"Label") as Label).text = "P%d" % (owner_slot + 1)
	var item := _items[_selected]
	title.text = tr(GameState.item_for(item.id).display_name)
	var owner_slot := GameState.owner_of(item.id)
	var ammo: ItemData = item.behavior.ammo if item.behavior else null
	if owner_slot not in [-1, mine]:
		detail.text = tr("HUD_RING_TAKEN").format({player = "P%d" % (owner_slot + 1)})
	elif ammo:
		detail.text = "%d / %d" % [GameState.inventory.count(ammo.id), GameState.inventory.capacity(ammo.id)]
	else:
		detail.text = ""
	hint_x.texture = InputPrompts.icon_for(PlayerCharacter.ITEM_ACTIONS[0], player)
	hint_y.texture = InputPrompts.icon_for(PlayerCharacter.ITEM_ACTIONS[1], player)


func _on_inventory_changed(_id: StringName, _count: int) -> void:
	_refresh()


func _color_of(slot: int) -> Color:
	return _colors[slot] if slot < _colors.size() else Color.WHITE
