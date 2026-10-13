extends Control
## Pestaña Ítems: ítems secundarios para asignar a X/Y (item_1/item_2), la fila fija de las cuatro botellas, objetos de
## la mazmorra y detalle.
## En co-op, en vez del detalle, una tarjeta por player con lo que lleva (13.9). Con el menú compartido cada invitado
## mueve su cursor con su control y asigna con X/Y; con el anillo, la pestaña solo muestra quién lleva qué.

const MapData := preload("res://src/ui/menus/map_data.gd")
const COLUMNS := 4
const SLOT_COUNT := 8
const BUTTON_ACTIONS: Array[StringName] = [&"item_1", &"item_2"]
const BUTTON_NAMES := ["X", "Y"]
const LOCK := preload("res://assets/ui/lock.svg")
const SLOT := preload("res://src/ui/menus/item_slot.tscn")
const CHIP := preload("res://src/ui/menus/dungeon_chip.tscn")
const ASSIGN_BUTTON := preload("res://src/ui/menus/assign_button.tscn")
const CURSOR := preload("res://src/ui/menus/coop_cursor.tscn")
const CARD := preload("res://src/ui/menus/coop_card.tscn")
const DIRECTIONS := {&"ui_left": Vector2i.LEFT, &"ui_right": Vector2i.RIGHT, &"ui_up": Vector2i.UP, &"ui_down": Vector2i.DOWN}

## Lo lee el menú de pausa para la barra de ayuda.
var accept_label := ""

@onready var grid: GridContainer = %Grid
@onready var bottle_grid: GridContainer = %BottleGrid
@onready var dungeon_box: VBoxContainer = %Dungeon
@onready var dungeon_title: Label = %DungeonTitle
@onready var chips: HFlowContainer = %Chips
@onready var detail: PanelContainer = %Detail
@onready var coop_box: VBoxContainer = %Coop
@onready var cards: VBoxContainer = %Cards
@onready var coop_hint: Label = %CoopHint

var _slots: Dictionary[Button, ItemData] = {}
## Slot de cada invitado → su cursor (con el menú compartido) y el índice del slot de la grilla donde está.
var _cursors: Dictionary[int, Control] = {}
var _cursor_at: Dictionary[int, int] = {}
var _refresh_queued := false


func _ready() -> void:
	grid.columns = COLUMNS
	_build_slots()
	GameState.inventory.changed.connect(_queue_refresh.unbind(2))
	GameState.item_buttons_changed.connect(_queue_refresh)
	GameState.loaded.connect(_queue_refresh)
	InputDevice.input_device_changed.connect(_queue_refresh.unbind(1))
	Settings.changed.connect(_queue_refresh.unbind(1))
	Players.joined.connect(_queue_refresh.unbind(1))
	Players.left.connect(_queue_refresh.unbind(1))
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_queue_refresh()


func focus_default() -> void:
	for slot in _slots:
		if _is_assignable(_slots[slot]):
			slot.grab_focus()
			return
	_cells()[0].grab_focus()


## El control de un invitado mueve su cursor y asigna; no llega al foco del menú (que es del primero).
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not Players.uses_shared_item_menu():
		return
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	var slot := Players.slot_of_pad(event.device)
	if slot < 1:
		return
	for action: StringName in DIRECTIONS:
		if event.is_action_pressed(action, true):
			_move_cursor(slot, DIRECTIONS[action])
			get_viewport().set_input_as_handled()
			return
	for i in BUTTON_ACTIONS.size():
		if event.is_action_pressed(BUTTON_ACTIONS[i]):
			_assign_at(slot, i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _can_assign():
		return
	for i in BUTTON_ACTIONS.size():
		if event.is_action_pressed(BUTTON_ACTIONS[i]) and _assign_focused(i):
			get_viewport().set_input_as_handled()
			return


func _assign_focused(button: int) -> bool:
	var item: ItemData = _slots.get(get_viewport().gui_get_focus_owner())
	if item == null or not _is_assignable(item):
		return false
	if not GameState.assign_button(button, item.id):
		Feel.sfx(&"deny", Vector3.ZERO)
	return true


func _can_assign() -> bool:
	return Players.all.size() <= 1 or Players.uses_shared_item_menu()


func _move_cursor(slot: int, step: Vector2i) -> void:
	var count := _cells().size()
	var at := _cursor_at.get(slot, 0) as int
	var cell := Vector2i(at % COLUMNS, at / COLUMNS) + step
	if cell.x < 0 or cell.x >= COLUMNS or cell.y < 0 or cell.y * COLUMNS + cell.x >= count:
		return
	_cursor_at[slot] = cell.y * COLUMNS + cell.x
	_place_cursors()


func _assign_at(slot: int, button: int) -> void:
	var item: ItemData = _slots.get(_cells()[_cursor_at.get(slot, 0)])
	if item == null or not _is_assignable(item) or not GameState.assign_button(button, item.id, slot):
		Feel.sfx(&"deny", Vector3.ZERO)


func _build_slots() -> void:
	var usables := Items.database.items.filter(func(item: ItemData) -> bool:
		return item.category == ItemData.Category.USABLE and not item.bottled and item.id not in GameState.BOTTLES)
	for i in SLOT_COUNT:
		_add_slot(grid, usables[i] if i < usables.size() else null)
	for bottle in GameState.BOTTLES:
		_add_slot(bottle_grid, Items.get_item(bottle))


func _add_slot(parent: GridContainer, item: ItemData) -> void:
	var slot: Button = SLOT.instantiate()
	if item:
		_slots[slot] = item
	else:
		slot.disabled = true
		slot.icon = LOCK
	slot.focus_entered.connect(_show_detail.bind(slot))
	slot.mouse_entered.connect(slot.grab_focus)
	parent.add_child(slot)


## Las casillas en el orden del cursor: la grilla y después la fila de botellas (las dos de COLUMNS columnas).
func _cells() -> Array[Node]:
	return grid.get_children() + bottle_grid.get_children()


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
		var bottle := item.id in GameState.BOTTLES
		slot.icon = GameState.item_for(item.id).icon if owned else Items.get_item(GameState.EMPTY_BOTTLE).icon if bottle else LOCK
		var owner_slot := GameState.owner_of(item.id)
		var holder := _player(owner_slot)
		var button := GameState.buttons_of(owner_slot).find(item.id) if owner_slot != -1 else -1
		var badge := slot.get_node(^"Badge") as TextureRect
		badge.visible = owned and button != -1
		if badge.visible:
			badge.texture = InputPrompts.icon_for(BUTTON_ACTIONS[button], holder) if holder else InputPrompts.icon_for_current(BUTTON_ACTIONS[button])
		var owner_tag := slot.get_node(^"Owner") as PanelContainer
		owner_tag.visible = owned and owner_slot != -1 and Players.all.size() > 1
		if owner_tag.visible:
			owner_tag.self_modulate = _color(owner_slot)
			(owner_tag.get_node(^"Label") as Label).text = "P%d" % (owner_slot + 1)
		var count := slot.get_node(^"Count") as Label
		var ammo := _ammo(item)
		count.visible = owned and ammo != null
		if count.visible:
			count.text = str(GameState.inventory.count(ammo.id))
	_refresh_dungeon()
	_refresh_coop()
	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused and focused in _cells():
		_show_detail(focused)


func _refresh_dungeon() -> void:
	dungeon_box.visible = GameState.current_dungeon != &""
	if not dungeon_box.visible:
		return
	var dungeon_node := MapData.find(get_tree(), Dungeon) as Dungeon
	dungeon_title.text = tr(dungeon_node.display_name).to_upper() if dungeon_node else ""
	for child in chips.get_children():
		chips.remove_child(child)
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
		detail.actions.remove_child(child)
		child.queue_free()
	var item: ItemData = _slots.get(slot)
	if item and item.id in GameState.BOTTLES and not GameState.inventory.has(item.id):
		detail.show_item(Items.get_item(GameState.EMPTY_BOTTLE).icon, "ITEMS_BOTTLE_MISSING", "", "ITEMS_BOTTLE_MISSING_DESC")
		return
	if item == null or not GameState.inventory.has(item.id):
		detail.show_item(LOCK, "ITEMS_UNDISCOVERED", "", "ITEMS_UNDISCOVERED_DESC")
		return
	var shown := GameState.item_for(item.id)
	detail.show_item(shown.icon, shown.display_name, "ITEMS_KIND", shown.description)
	var ammo := _ammo(item)
	if ammo:
		detail.add_stat(ammo.display_name, "%d / %d" % [GameState.inventory.count(ammo.id), GameState.inventory.capacity(ammo.id)])
	for i in BUTTON_ACTIONS.size():
		detail.actions.add_child(_assign_button(i, GameState.item_buttons[i] == item.id))


func _assign_button(index: int, assigned: bool) -> Button:
	var button: Button = ASSIGN_BUTTON.instantiate()
	button.text = tr("ITEMS_ASSIGNED" if assigned else "ITEMS_ASSIGN").format({button = BUTTON_NAMES[index]})
	button.icon = InputPrompts.icon_for_current(BUTTON_ACTIONS[index])
	button.theme_type_variation = &"AssignButtonActive" if assigned else &"AssignButton"
	button.pressed.connect(_assign_focused.bind(index))
	return button


func _refresh_coop() -> void:
	var coop := Players.all.size() > 1
	detail.visible = not coop
	coop_box.visible = coop
	coop_hint.text = "ITEMS_COOP_SHARED_HINT" if Players.uses_shared_item_menu() else "ITEMS_COOP_RING_HINT"
	for card in cards.get_children():
		cards.remove_child(card)
		card.queue_free()
	if coop:
		for player in Players.all:
			cards.add_child(_card(player))
	_place_cursors()


func _card(player: PlayerCharacter) -> Control:
	var card: Control = CARD.instantiate()
	var slot := player.controls.slot
	card.get_node(^"Border").self_modulate = _color(slot)
	var tag := card.get_node(^"Row/Tag") as PanelContainer
	tag.self_modulate = _color(slot)
	(tag.get_node(^"Label") as Label).text = "P%d" % (slot + 1)
	var buttons := GameState.buttons_of(slot)
	for i in BUTTON_ACTIONS.size():
		var row := card.get_node(^"Row/Buttons").get_child(i)
		var item := GameState.item_for(buttons[i])
		(row.get_node(^"Badge") as TextureRect).texture = InputPrompts.icon_for(BUTTON_ACTIONS[i], player)
		(row.get_node(^"Icon") as TextureRect).texture = item.icon if item else null
		(row.get_node(^"Name") as Label).text = tr(item.display_name) if item else "—"
	return card


func _place_cursors() -> void:
	var guests: Array[int] = []
	if Players.uses_shared_item_menu():
		for player in Players.all:
			if player.controls.slot > 0:
				guests.append(player.controls.slot)
	for slot in _cursors.keys():
		if slot not in guests:
			_cursors[slot].queue_free()
			_cursors.erase(slot)
			_cursor_at.erase(slot)
	for slot in guests:
		if not _cursors.has(slot):
			var cursor: Control = CURSOR.instantiate()
			cursor.get_node(^"Frame").self_modulate = _color(slot)
			cursor.get_node(^"Tag").self_modulate = _color(slot)
			(cursor.get_node(^"Tag/Label") as Label).text = "P%d" % (slot + 1)
			_cursors[slot] = cursor
		var target := _cells()[_cursor_at.get(slot, 0)]
		if _cursors[slot].get_parent() != target:
			if _cursors[slot].get_parent():
				_cursors[slot].reparent(target, false)
			else:
				target.add_child(_cursors[slot])


func cursor_of(slot: int) -> int:
	return _cursor_at.get(slot, 0)


func _player(slot: int) -> PlayerCharacter:
	for player in Players.all:
		if player.controls.slot == slot:
			return player
	return null


func _color(slot: int) -> Color:
	var hud := get_tree().get_first_node_in_group(&"hud")
	var colors: Array = hud.player_colors if hud else []
	return colors[slot] if slot < colors.size() else Color.WHITE


func _is_assignable(item: ItemData) -> bool:
	return item.category == ItemData.Category.USABLE and GameState.inventory.has(item.id)


func _ammo(item: ItemData) -> ItemData:
	return item.behavior.ammo if item.behavior else null
