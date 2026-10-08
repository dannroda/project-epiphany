@tool
extends "tab.gd"

const C := ItemData.Category
const GROUPS := [["EQUIPO", [C.SWORD, C.SHIELD, C.ARMOR]], ["USABLES", [C.USABLE]], ["MUNICIÓN", [C.AMMO]], ["MEJORAS", [C.UPGRADE]]]

var _search := LineEdit.new()
var _list := VBoxContainer.new()


func _init() -> void:
	name = "Inventario"
	var bar := HBoxContainer.new()
	_search.placeholder_text = "Buscar ítem…"
	_search.size_flags_horizontal = SIZE_EXPAND_FILL
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t: String) -> void: refresh())
	bar.add_child(_search)
	bar.add_child(button("Todo al máximo", _fill_all))
	bar.add_child(button("Vaciar", _clear_all))
	add_child(bar)
	add_child(_list)


func refresh() -> void:
	clear(_list)
	var query := _search.text.strip_edges().to_lower()
	for group in GROUPS:
		var items := db.items.filter(func(item: ItemData) -> bool:
			return item.category in group[1] and (query.is_empty() or query in String(item.id) or query in item.display_name.to_lower()))
		if items.is_empty():
			continue
		_list.add_child(group_label(group[0]))
		for item: ItemData in items:
			_list.add_child(_row(item))
	var unknown := _unknown_ids()
	if not unknown.is_empty():
		_list.add_child(group_label("NO EXISTEN EN LA BASE", editor_color(&"error_color")))
		for id in unknown:
			var row := HBoxContainer.new()
			var label := Label.new()
			label.text = "%s = %s" % [id, cfg.get_value("inventory", id)]
			label.size_flags_horizontal = SIZE_EXPAND_FILL
			label.add_theme_color_override(&"font_color", editor_color(&"error_color"))
			row.add_child(label)
			row.add_child(button("Quitar", func() -> void: _set_count(id, 0)))
			_list.add_child(row)
	_list.add_child(dim_label("Llaves, mapa y brújula van por mazmorra: pestaña Mazmorras."))


func _row(item: ItemData) -> HBoxContainer:
	var row := HBoxContainer.new()
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = item.icon if item.icon else get_theme_icon(&"Object", &"EditorIcons")
	row.add_child(icon)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = SIZE_EXPAND_FILL
	names.add_theme_constant_override(&"separation", 0)
	var title := Label.new()
	title.text = item.display_name
	names.add_child(title)
	names.add_child(dim_label(item.id))
	row.add_child(names)
	var count: int = cfg.get_value("inventory", item.id, 0)
	if item.max_stack == 1:
		var toggle := CheckButton.new()
		toggle.button_pressed = count > 0
		toggle.toggled.connect(func(on: bool) -> void: _set_count(item.id, 1 if on else 0))
		row.add_child(toggle)
	else:
		row.add_child(stepper(count, item.max_stack, func(n: int) -> void: _set_count(item.id, n)))
	return row


func _set_count(id: StringName, count: int) -> void:
	set_or_erase("inventory", id, count, 0)
	mark_edited()
	refresh()


func _fill_all() -> void:
	for group in GROUPS:
		for item in db.items:
			if item.category in group[1]:
				cfg.set_value("inventory", item.id, item.max_stack)
	mark_edited()
	refresh()


func _clear_all() -> void:
	if cfg.has_section("inventory"):
		cfg.erase_section("inventory")
	mark_edited()
	refresh()


func _unknown_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	if cfg.has_section("inventory"):
		for id in cfg.get_section_keys("inventory"):
			if not db.has_item(id):
				ids.append(id)
	return ids
