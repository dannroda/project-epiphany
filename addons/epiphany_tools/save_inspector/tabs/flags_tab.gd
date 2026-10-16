@tool
extends "tab.gd"

const FlagUsages := preload("../flag_usages.gd")

const GROUPS := {
	"ow": "Overworld", "ch": "Chullpa (D1)", "qv": "Queñoa (D2)", "tt": "Totora (D3)", "cu": "Cumbre (D4)",
	"te": "Templo", "d0": "Salas de prueba", "d1": "Salas de prueba",
}

var _search := LineEdit.new()
var _only_changed := CheckBox.new()
var _list := VBoxContainer.new()
var _folded := {}
var _usages := FlagUsages.new()


func _init() -> void:
	name = "Flags"
	var header := HBoxContainer.new()
	_search.placeholder_text = "Buscar por id o descripción"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_text: String) -> void: refresh())
	header.add_child(_search)
	_only_changed.text = "Solo cambiadas"
	_only_changed.tooltip_text = "Las que no tienen su valor por defecto"
	_only_changed.toggled.connect(func(_on: bool) -> void: refresh())
	header.add_child(_only_changed)
	add_child(header)
	add_child(_list)


func _ready() -> void:
	_search.right_icon = get_theme_icon(&"Search", &"EditorIcons")


## Para que vuelva a buscar dónde se usa cada flag (Recargar del dock).
func reindex() -> void:
	_usages.built = false


func refresh() -> void:
	if not _usages.built:
		_usages.build(flags.definitions.filter(func(d: FlagDefinition) -> bool: return d != null).map(func(d: FlagDefinition) -> StringName: return d.id))
	clear(_list)
	var query := _search.text.strip_edges().to_lower()
	var groups := {}
	for definition in flags.definitions:
		if definition == null or not _matches(definition, query):
			continue
		var group := _group_of(definition.id)
		if not groups.has(group):
			groups[group] = []
		groups[group].append(definition)
	var order := GROUPS.values()
	var titles := groups.keys()
	titles.sort_custom(func(a: String, b: String) -> bool: return _rank(order, a) < _rank(order, b))
	for group: String in titles:
		_list.add_child(_group(group, groups[group], not query.is_empty() or _only_changed.button_pressed))
	if groups.is_empty():
		_list.add_child(dim_label("Ninguna flag coincide"))
	_add_unknown()


func _matches(definition: FlagDefinition, query: String) -> bool:
	if _only_changed.button_pressed and not _changed(definition):
		return false
	return query.is_empty() or query in String(definition.id).to_lower() or query in definition.description.to_lower()


func _changed(definition: FlagDefinition) -> bool:
	return cfg.get_value("flags", definition.id, definition.default_value) != definition.default_value


func _rank(order: Array, title: String) -> int:
	var index := order.find(title)
	return index if index >= 0 else order.size()


func _group_of(id: StringName) -> String:
	return GROUPS.get(String(id).get_slice("_", 0), "Otras")


func _group(title: String, definitions: Array, open: bool) -> FoldableContainer:
	var box := FoldableContainer.new()
	box.title = "%s · %d/%d cambiadas" % [title, definitions.filter(_changed).size(), definitions.size()]
	box.folded = _folded.get(title, true) and not open
	box.folding_changed.connect(func(is_folded: bool) -> void: _folded[title] = is_folded)
	var all_on := button("Todas", func() -> void: _set_group(definitions, true))
	all_on.tooltip_text = "Prende todas las flags de sí/no de este grupo"
	var reset := button("Por defecto", func() -> void: _set_group(definitions, false))
	reset.tooltip_text = "Vuelve todas las de este grupo a su valor por defecto"
	for control: Button in [all_on, reset]:
		control.flat = true
		control.add_theme_font_size_override(&"font_size", 11)
		box.add_title_bar_control(control)
	var rows := VBoxContainer.new()
	for definition: FlagDefinition in definitions:
		rows.add_child(_row(definition))
	box.add_child(rows)
	return box


func _add_unknown() -> void:
	var unknown := PackedStringArray()
	if cfg.has_section("flags"):
		for id in cfg.get_section_keys("flags"):
			if not flags.has(id):
				unknown.append(id)
	if unknown.is_empty():
		return
	_list.add_child(group_label("NO REGISTRADAS", editor_color(&"error_color")))
	for id in unknown:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s = %s" % [id, var_to_str(cfg.get_value("flags", id))]
		label.tooltip_text = "No está en flag_registry.tres. El juego la ignora."
		label.mouse_filter = MOUSE_FILTER_PASS
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		label.add_theme_color_override(&"font_color", editor_color(&"error_color"))
		row.add_child(label)
		row.add_child(button("Quitar", func() -> void:
			cfg.erase_section_key("flags", id)
			mark_edited()))
		_list.add_child(row)


func _row(definition: FlagDefinition) -> HBoxContainer:
	var row := HBoxContainer.new()
	var value: Variant = cfg.get_value("flags", definition.id, definition.default_value)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = SIZE_EXPAND_FILL
	names.add_theme_constant_override(&"separation", 0)
	var title := Label.new()
	title.text = definition.id
	if value != definition.default_value:
		title.add_theme_color_override(&"font_color", editor_color(&"accent_color"))
	names.add_child(title)
	names.add_child(dim_label("%s · por defecto: %s" % [definition.description, var_to_str(definition.default_value)]))
	row.add_child(names)
	row.add_child(_usage_menu(definition.id))
	if typeof(definition.default_value) == TYPE_BOOL:
		var toggle := CheckButton.new()
		toggle.button_pressed = bool(value)
		toggle.toggled.connect(func(on: bool) -> void: _set_flag(definition, on))
		row.add_child(toggle)
	else:
		var edit := LineEdit.new()
		edit.text = var_to_str(value)
		edit.custom_minimum_size.x = 100
		edit.text_submitted.connect(func(text: String) -> void: _set_flag(definition, str_to_var(text)))
		row.add_child(edit)
	return row


func _usage_menu(id: StringName) -> Control:
	var uses := _usages.of(id)
	if uses.is_empty():
		var none := Label.new()
		none.text = "sin uso"
		none.tooltip_text = "No aparece en levels/, src/, data/ ni tests/. Puede estar armada en código, o no la usa nadie."
		none.mouse_filter = MOUSE_FILTER_PASS
		none.add_theme_font_size_override(&"font_size", 11)
		none.add_theme_color_override(&"font_color", editor_color(&"warning_color"))
		return none
	var menu := MenuButton.new()
	menu.text = "Ver (%d)" % uses.size()
	menu.tooltip_text = "Dónde se usa"
	menu.add_theme_font_size_override(&"font_size", 11)
	var popup := menu.get_popup()
	for i in uses.size():
		var use: Dictionary = uses[i]
		var where: String = use.path.get_file()
		popup.add_item("%s · %s" % [where, use.node] if not String(use.node).is_empty() else "%s:%d" % [where, use.line], i)
	popup.id_pressed.connect(func(index: int) -> void: _go_to(uses[index]))
	return menu


func _go_to(use: Dictionary) -> void:
	var path: String = use.path
	match path.get_extension():
		"tscn":
			EditorInterface.open_scene_from_path(path)
			var root := EditorInterface.get_edited_scene_root()
			var node := root.get_node_or_null(NodePath(use.node)) if root and not String(use.node).is_empty() else null
			if node:
				EditorInterface.edit_node(node)
				EditorInterface.get_selection().clear()
				EditorInterface.get_selection().add_node(node)
		"gd":
			EditorInterface.edit_script(load(path), use.line)
			EditorInterface.set_main_screen_editor("Script")
		_:
			EditorInterface.select_file(path)
			EditorInterface.edit_resource(load(path))


func _set_group(definitions: Array, on: bool) -> void:
	for definition: FlagDefinition in definitions:
		if not on:
			set_or_erase("flags", definition.id, definition.default_value, definition.default_value)
		elif typeof(definition.default_value) == TYPE_BOOL:
			set_or_erase("flags", definition.id, true, definition.default_value)
	mark_edited()


func _set_flag(definition: FlagDefinition, value: Variant) -> void:
	set_or_erase("flags", definition.id, value, definition.default_value)
	mark_edited()
