extends Control
## Pestaña Ítems: ítems secundarios para asignar a X/Y (item_1/item_2), mejoras y detalle.

const COLUMNS := 4
const SLOT_COUNT := 8
const BUTTON_ACTIONS: Array[StringName] = [&"item_1", &"item_2"]
const LOCK := preload("res://assets/ui/lock.svg")

## Los lee el menú de pausa para la barra de ayuda.
var accept_label := ""
var extra_hints := [[&"item_1", ""], [&"item_2", "Asignar"]]

@onready var button_row: HBoxContainer = %ButtonRow
@onready var grid: GridContainer = %Grid
@onready var upgrades_title: Label = %UpgradesTitle
@onready var upgrades: HBoxContainer = %Upgrades
@onready var detail: PanelContainer = %Detail

var _slots: Dictionary[Button, ItemData] = {}
var _button_icons: Array[TextureRect] = []
var _button_names: Array[Label] = []
var _button_prompts: Array[TextureRect] = []
var _refresh_queued := false


func _ready() -> void:
	grid.columns = COLUMNS
	_build_buttons()
	_build_slots()
	GameState.inventory.changed.connect(func(_id: StringName, _count: int) -> void: _queue_refresh())
	GameState.item_buttons_changed.connect(_queue_refresh)
	GameState.loaded.connect(_queue_refresh)
	InputDevice.input_device_changed.connect(func(_d: int) -> void: _refresh())
	_refresh()


func focus_default() -> void:
	for slot in _slots:
		if _is_assignable(_slots[slot]):
			slot.grab_focus()
			return
	grid.get_child(0).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	for i in BUTTON_ACTIONS.size():
		if event.is_action_pressed(BUTTON_ACTIONS[i]):
			var item: ItemData = _slots.get(get_viewport().gui_get_focus_owner())
			if item and _is_assignable(item):
				GameState.assign_button(i, item.id)
				get_viewport().set_input_as_handled()
			return


func _build_buttons() -> void:
	for i in BUTTON_ACTIONS.size():
		var column := VBoxContainer.new()
		column.add_theme_constant_override(&"separation", 8)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		var frame := PanelContainer.new()
		frame.theme_type_variation = &"Slot"
		frame.custom_minimum_size = Vector2(120, 120)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.add_child(icon)
		var prompt := TextureRect.new()
		prompt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		prompt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		prompt.custom_minimum_size = Vector2(36, 36)
		var label := Label.new()
		label.theme_type_variation = &"Hint"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(prompt)
		column.add_child(frame)
		column.add_child(label)
		button_row.add_child(column)
		_button_icons.append(icon)
		_button_prompts.append(prompt)
		_button_names.append(label)


func _build_slots() -> void:
	var usables := Items.database.items.filter(func(item: ItemData) -> bool: return item.category == ItemData.Category.USABLE)
	for i in SLOT_COUNT:
		grid.add_child(_make_slot(usables[i] if i < usables.size() else null))
	for item in Items.database.items:
		if item.category == ItemData.Category.UPGRADE:
			upgrades.add_child(_make_slot(item))


func _make_slot(item: ItemData) -> Button:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(96, 96)
	slot.theme_type_variation = &"EquipSlot"
	slot.expand_icon = true
	slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.focus_mode = FOCUS_ALL
	if item:
		_slots[slot] = item
	else:
		slot.disabled = true
		slot.icon = LOCK
	var badge := TextureRect.new()
	badge.name = "Badge"
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.size = Vector2(28, 28)
	badge.position = Vector2(4, 4)
	badge.mouse_filter = MOUSE_FILTER_IGNORE
	badge.visible = false
	slot.add_child(badge)
	var count := Label.new()
	count.name = "Count"
	count.theme_type_variation = &"KeyHint"
	count.mouse_filter = MOUSE_FILTER_IGNORE
	count.visible = false
	count.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT, PRESET_MODE_MINSIZE, 6)
	count.grow_horizontal = GROW_DIRECTION_BEGIN
	count.grow_vertical = GROW_DIRECTION_BEGIN
	slot.add_child(count)
	slot.focus_entered.connect(_show_detail.bind(slot))
	slot.mouse_entered.connect(slot.grab_focus)
	return slot


func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	var any_upgrade := false
	for slot in _slots:
		var item := _slots[slot]
		var owned := GameState.inventory.has(item.id)
		slot.disabled = not owned
		slot.icon = item.icon if owned else LOCK
		var button := GameState.item_buttons.find(item.id)
		var badge := slot.get_node(^"Badge") as TextureRect
		badge.visible = owned and button != -1
		if badge.visible:
			badge.texture = InputPrompts.icon_for_current(BUTTON_ACTIONS[button])
		var count := slot.get_node(^"Count") as Label
		var ammo := _ammo(item)
		count.visible = owned and ammo != null
		if count.visible:
			count.text = str(GameState.inventory.count(ammo.id))
		if item.category == ItemData.Category.UPGRADE:
			slot.visible = owned
			any_upgrade = any_upgrade or owned
	upgrades_title.visible = any_upgrade
	for i in BUTTON_ACTIONS.size():
		var item := Items.get_item(GameState.item_buttons[i]) if GameState.item_buttons[i] != &"" else null
		_button_icons[i].texture = item.icon if item else null
		_button_names[i].text = item.display_name if item else "Vacío"
		_button_prompts[i].texture = InputPrompts.icon_for_current(BUTTON_ACTIONS[i])
	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused and focused.get_parent() in [grid, upgrades]:
		_show_detail(focused)


func _show_detail(slot: Button) -> void:
	var item: ItemData = _slots.get(slot)
	if item == null or not GameState.inventory.has(item.id):
		detail.show_item(LOCK, "Sin descubrir", "", "Todavía no encontraste este ítem.")
		return
	var kind := "Mejora" if item.category == ItemData.Category.UPGRADE else "Ítem"
	if GameState.item_buttons.has(item.id):
		kind += " · asignado"
	detail.show_item(item.icon, item.display_name, kind, item.description)
	var ammo := _ammo(item)
	if ammo:
		detail.add_stat(ammo.display_name, "%d / %d" % [GameState.inventory.count(ammo.id), GameState.inventory.capacity(ammo.id)])


func _is_assignable(item: ItemData) -> bool:
	return item.category == ItemData.Category.USABLE and GameState.inventory.has(item.id)


func _ammo(item: ItemData) -> ItemData:
	return item.behavior.ammo if item.behavior else null
