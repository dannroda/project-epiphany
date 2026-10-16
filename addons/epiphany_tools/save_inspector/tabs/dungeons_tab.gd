@tool
extends "tab.gd"

const PREFIX := SaveKeys.DUNGEON_PREFIX
const ROOMS := 24
const FLAGS := [["has_map", "Mapa"], ["has_compass", "Brújula"], ["has_boss_key", "Llave del jefe"]]

var _new_id := LineEdit.new()


func _init() -> void:
	name = "Mazmorras"
	_new_id.placeholder_text = "id (p. ej. d1)"


func refresh() -> void:
	clear(self)
	var current := String(cfg.get_value(SaveKeys.PLAYER, SaveKeys.CURRENT_DUNGEON, &""))
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for section in cfg.get_sections():
		if section.begins_with(PREFIX):
			add_child(_card(section, section.trim_prefix(PREFIX), current, group))
	var add_row := HBoxContainer.new()
	_new_id.size_flags_horizontal = SIZE_EXPAND_FILL
	if _new_id.get_parent():
		_new_id.get_parent().remove_child(_new_id)
	add_row.add_child(_new_id)
	add_row.add_child(button("Agregar mazmorra", _add))
	add_child(add_row)


func _card(section: String, id: String, current: String, group: ButtonGroup) -> PanelContainer:
	var card := PanelContainer.new()
	var box := VBoxContainer.new()
	card.add_child(box)
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = id
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	var is_current := CheckBox.new()
	is_current.text = "Mazmorra actual"
	is_current.button_group = group
	is_current.button_pressed = id == current
	is_current.toggled.connect(func(on: bool) -> void:
		set_or_erase(SaveKeys.PLAYER, SaveKeys.CURRENT_DUNGEON, StringName(id) if on else &"", &"")
		mark_edited())
	header.add_child(is_current)
	header.add_child(button("Quitar", func() -> void:
		cfg.erase_section(section)
		mark_edited()
		refresh()))
	box.add_child(header)

	var keys_row := HBoxContainer.new()
	var keys_label := Label.new()
	keys_label.text = "Llaves chicas"
	keys_label.size_flags_horizontal = SIZE_EXPAND_FILL
	keys_row.add_child(keys_label)
	var key_item := db.get_item(&"small_key")
	var set_keys := func(n: int) -> void:
		cfg.set_value(section, SaveKeys.SMALL_KEYS, n)
		mark_edited()
		refresh()
	keys_row.add_child(stepper(cfg.get_value(section, SaveKeys.SMALL_KEYS, 0), key_item.max_stack if key_item else 9, set_keys, false))
	box.add_child(keys_row)

	var checks := HFlowContainer.new()
	for flag in FLAGS:
		var check := CheckBox.new()
		check.text = flag[1]
		check.button_pressed = cfg.get_value(section, flag[0], false)
		check.toggled.connect(func(on: bool) -> void:
			cfg.set_value(section, flag[0], on)
			mark_edited())
		checks.add_child(check)
	box.add_child(checks)

	var visited: int = cfg.get_value(section, SaveKeys.VISITED_ROOMS, 0)
	var count := 0
	for n in ROOMS:
		count += (visited >> n) & 1
	box.add_child(dim_label("Salas visitadas · %d de %d" % [count, ROOMS]))
	var grid := GridContainer.new()
	grid.columns = 6
	for n in ROOMS:
		var room := Button.new()
		room.toggle_mode = true
		room.custom_minimum_size = Vector2(28, 28)
		room.size_flags_horizontal = SIZE_EXPAND_FILL
		room.tooltip_text = "Sala %d" % n
		room.button_pressed = (visited >> n) & 1 == 1
		room.toggled.connect(func(on: bool) -> void:
			var bits: int = cfg.get_value(section, SaveKeys.VISITED_ROOMS, 0)
			bits = (bits | (1 << n)) if on else (bits & ~(1 << n))
			cfg.set_value(section, SaveKeys.VISITED_ROOMS, bits)
			mark_edited()
			refresh())
		grid.add_child(room)
	box.add_child(grid)
	return card


func _add() -> void:
	var id := _new_id.text.strip_edges()
	if not id.is_valid_identifier() or cfg.has_section(PREFIX + id):
		return
	cfg.set_value(PREFIX + id, "small_keys", 0)
	_new_id.clear()
	mark_edited()
	refresh()
