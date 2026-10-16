@tool
extends "tab.gd"

const C := ItemData.Category
const SLOTS := [["Espada", C.SWORD], ["Escudo", C.SHIELD], ["Armadura", C.ARMOR]]
const NONE := "(ninguno)"
const EMPTY := "(vacío)"


func _init() -> void:
	name = "Equipo"


func refresh() -> void:
	clear(self)
	for slot in SLOTS:
		add_child(dim_label(slot[0]))
		var key: String = C.find_key(slot[1])
		var items := db.items.filter(func(item: ItemData) -> bool: return item.category == slot[1])
		add_child(_picker(items, cfg.get_value(SaveKeys.EQUIPMENT, key, &""), NONE, func(id: StringName) -> void: _equip(key, id)))
	var buttons: Array = cfg.get_value(SaveKeys.EQUIPMENT, SaveKeys.BUTTONS, [&"", &""])
	var usables := db.items.filter(func(item: ItemData) -> bool: return item.category == C.USABLE)
	var grid := GridContainer.new()
	grid.columns = 2
	for i in 2:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = SIZE_EXPAND_FILL
		column.add_child(dim_label("Botón %s" % ["X", "Y"][i]))
		column.add_child(_picker(usables, buttons[i] if i < buttons.size() else &"", EMPTY, func(id: StringName) -> void: _assign_button(i, id)))
		grid.add_child(column)
	add_child(grid)
	add_child(dim_label("Equipar un ítem que no está en el inventario lo agrega."))


func _picker(items: Array, selected: StringName, empty_text: String, on_pick: Callable) -> OptionButton:
	var picker := OptionButton.new()
	picker.add_item(empty_text)
	picker.set_item_metadata(0, &"")
	for item: ItemData in items:
		picker.add_item("%s · %s" % [item.display_name, item.id])
		picker.set_item_metadata(picker.item_count - 1, item.id)
		if item.id == selected:
			picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(index: int) -> void: on_pick.call(picker.get_item_metadata(index)))
	return picker


func _equip(key: String, id: StringName) -> void:
	set_or_erase(SaveKeys.EQUIPMENT, key, id, &"")
	_ensure_owned(id)
	mark_edited()


func _assign_button(index: int, id: StringName) -> void:
	var buttons: Array[StringName] = [&"", &""]
	buttons.assign(cfg.get_value(SaveKeys.EQUIPMENT, SaveKeys.BUTTONS, [&"", &""]))
	buttons.resize(2)
	buttons[index] = id
	cfg.set_value(SaveKeys.EQUIPMENT, SaveKeys.BUTTONS, buttons)
	_ensure_owned(id)
	mark_edited()


func _ensure_owned(id: StringName) -> void:
	if id != &"" and int(cfg.get_value(SaveKeys.INVENTORY, id, 0)) == 0:
		cfg.set_value(SaveKeys.INVENTORY, id, 1)
