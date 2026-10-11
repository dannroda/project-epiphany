extends Control
## Pestaña Ítems: ítems secundarios para asignar a X/Y (item_1/item_2), objetos de la mazmorra y detalle.

const MapData := preload("res://src/ui/menus/map_data.gd")
const COLUMNS := 4
const SLOT_COUNT := 12
const BUTTON_ACTIONS: Array[StringName] = [&"item_1", &"item_2"]
const BUTTON_NAMES := ["X", "Y"]
const LOCK := preload("res://assets/ui/lock.svg")
const SLOT := preload("res://src/ui/menus/item_slot.tscn")
const CHIP := preload("res://src/ui/menus/dungeon_chip.tscn")
const ASSIGN_BUTTON := preload("res://src/ui/menus/assign_button.tscn")

## Lo lee el menú de pausa para la barra de ayuda.
var accept_label := ""

@onready var grid: GridContainer = %Grid
@onready var dungeon_box: VBoxContainer = %Dungeon
@onready var dungeon_title: Label = %DungeonTitle
@onready var chips: HFlowContainer = %Chips
@onready var detail: PanelContainer = %Detail

var _slots: Dictionary[Button, ItemData] = {}
## En co-op cada uno asigna sus X / Y: muestra y edita los del último player que tocó algo en el menú.
var _player_slot := 0
var _refresh_queued := false


func _ready() -> void:
	grid.columns = COLUMNS
	_build_slots()
	GameState.inventory.changed.connect(func(_id: StringName, _count: int) -> void: _queue_refresh())
	GameState.item_buttons_changed.connect(_queue_refresh)
	GameState.loaded.connect(_queue_refresh)
	InputDevice.input_device_changed.connect(func(_d: int) -> void: _queue_refresh())
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_queue_refresh()


func focus_default() -> void:
	for slot in _slots:
		if _is_assignable(_slots[slot]):
			slot.grab_focus()
			return
	grid.get_child(0).grab_focus()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_pressed():
		return
	var slot := 0
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		slot = maxi(Players.slot_of_pad(event.device), 0)
	if slot != _player_slot:
		_player_slot = slot
		_queue_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	for i in BUTTON_ACTIONS.size():
		if event.is_action_pressed(BUTTON_ACTIONS[i]) and _assign_focused(i):
			get_viewport().set_input_as_handled()
			return


func _assign_focused(button: int) -> bool:
	var item: ItemData = _slots.get(get_viewport().gui_get_focus_owner())
	if item == null or not _is_assignable(item):
		return false
	GameState.assign_button(button, item.id, _player_slot)
	return true


func _build_slots() -> void:
	var usables := Items.database.items.filter(func(item: ItemData) -> bool: return item.category == ItemData.Category.USABLE)
	for i in SLOT_COUNT:
		var item: ItemData = usables[i] if i < usables.size() else null
		var slot: Button = SLOT.instantiate()
		if item:
			_slots[slot] = item
		else:
			slot.disabled = true
			slot.icon = LOCK
		slot.focus_entered.connect(_show_detail.bind(slot))
		slot.mouse_entered.connect(slot.grab_focus)
		grid.add_child(slot)


func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	for slot in _slots:
		var item := _slots[slot]
		var owned := GameState.inventory.has(item.id)
		slot.disabled = not owned
		slot.icon = item.icon if owned else LOCK
		var button := GameState.buttons_of(_player_slot).find(item.id)
		var badge := slot.get_node(^"Badge") as TextureRect
		badge.visible = owned and button != -1
		if badge.visible:
			badge.texture = InputPrompts.icon_for_current(BUTTON_ACTIONS[button])
		var count := slot.get_node(^"Count") as Label
		var ammo := _ammo(item)
		count.visible = owned and ammo != null
		if count.visible:
			count.text = str(GameState.inventory.count(ammo.id))
	_refresh_dungeon()
	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused and focused.get_parent() == grid:
		_show_detail(focused)


func _refresh_dungeon() -> void:
	dungeon_box.visible = GameState.current_dungeon != &""
	if not dungeon_box.visible:
		return
	var dungeon_node := MapData.find(get_tree(), Dungeon) as Dungeon
	dungeon_title.text = tr(dungeon_node.display_name).to_upper() if dungeon_node else ""
	for child in chips.get_children():
		child.queue_free()
	var dungeon := GameState.current_dungeon_state()
	_chip(&"small_key", tr("ITEMS_SMALL_KEYS").format({count = dungeon.small_keys}), dungeon.small_keys > 0)
	_chip(&"dungeon_map", "ITEMS_MAP", dungeon.has_map)
	_chip(&"compass", "ITEMS_COMPASS", dungeon.has_compass)
	_chip(&"boss_key", "ITEMS_BOSS_KEY" if dungeon.has_boss_key else "ITEMS_BOSS_KEY_NO", dungeon.has_boss_key)


func _chip(item_id: StringName, text: String, owned: bool) -> void:
	var chip: PanelContainer = CHIP.instantiate()
	chip.modulate = Color.WHITE if owned else Color(1, 1, 1, 0.55)
	(chip.get_node(^"Row/Icon") as TextureRect).texture = Items.get_item(item_id).icon
	(chip.get_node(^"Row/Label") as Label).text = text
	chips.add_child(chip)


func _show_detail(slot: Button) -> void:
	for child in detail.actions.get_children():
		child.queue_free()
	var item: ItemData = _slots.get(slot)
	if item == null or not GameState.inventory.has(item.id):
		detail.show_item(LOCK, "ITEMS_UNDISCOVERED", "", "ITEMS_UNDISCOVERED_DESC")
		return
	detail.show_item(item.icon, item.display_name, "ITEMS_KIND", item.description)
	var ammo := _ammo(item)
	if ammo:
		detail.add_stat(ammo.display_name, "%d / %d" % [GameState.inventory.count(ammo.id), GameState.inventory.capacity(ammo.id)])
	for i in BUTTON_ACTIONS.size():
		detail.actions.add_child(_assign_button(i, GameState.buttons_of(_player_slot)[i] == item.id))


func _assign_button(index: int, assigned: bool) -> Button:
	var button: Button = ASSIGN_BUTTON.instantiate()
	button.text = tr("ITEMS_ASSIGNED" if assigned else "ITEMS_ASSIGN").format({button = BUTTON_NAMES[index]})
	button.icon = InputPrompts.icon_for_current(BUTTON_ACTIONS[index])
	button.theme_type_variation = &"AssignButtonActive" if assigned else &"AssignButton"
	button.pressed.connect(_assign_focused.bind(index))
	return button


func _is_assignable(item: ItemData) -> bool:
	return item.category == ItemData.Category.USABLE and GameState.inventory.has(item.id)


func _ammo(item: ItemData) -> ItemData:
	return item.behavior.ammo if item.behavior else null
