@tool
extends "tab.gd"

const LEVELS_DIR := "res://levels"
const NO_SCENE := "(la escena de inicio)"
const FIRST_POINT := "(el primero de la escena)"
const SPAWN_SOURCES: Array[String] = ["res://src/world/spawn_point.gd", "res://src/world/spawn_point.tscn"]


func _init() -> void:
	name = "Partida"


func refresh() -> void:
	clear(self)
	var health: int = cfg.get_value("player", "max_health", 12)
	add_child(dim_label("Vida máxima"))
	var hearts := HBoxContainer.new()
	hearts.add_child(button("−", func() -> void: _set_health(maxi(4, health - 4))))
	var label := Label.new()
	label.text = "♥".repeat(ceili(health / 4.0))
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.add_theme_color_override(&"font_color", editor_color(&"error_color"))
	hearts.add_child(label)
	hearts.add_child(button("+", func() -> void: _set_health(health + 4)))
	hearts.add_child(dim_label("%d HP" % health))
	add_child(hearts)

	add_child(dim_label("Escena"))
	var scenes := OptionButton.new()
	scenes.add_item(NO_SCENE)
	var current: String = cfg.get_value("player", "spawn_scene", "")
	for file in DirAccess.get_files_at(LEVELS_DIR):
		if file.get_extension() == "tscn":
			scenes.add_item(LEVELS_DIR.path_join(file))
			if LEVELS_DIR.path_join(file) == current:
				scenes.select(scenes.item_count - 1)
	scenes.item_selected.connect(func(index: int) -> void:
		set_or_erase("player", "spawn_scene", "" if index == 0 else scenes.get_item_text(index), "")
		cfg.set_value("player", "spawn_point", &"")
		mark_edited())
	add_child(scenes)

	add_child(dim_label("Punto de aparición"))
	var points := OptionButton.new()
	var point: StringName = cfg.get_value("player", "spawn_point", &"")
	var ids := _spawn_ids(current)
	if point != &"" and not ids.has(String(point)):
		ids.append(String(point))
	points.add_item(FIRST_POINT)
	for id in ids:
		points.add_item(id)
		if id == String(point):
			points.select(points.item_count - 1)
	points.tooltip_text = "Los SpawnPoint de la escena (sus id); con la posición guardada, manda la posición"
	points.item_selected.connect(func(index: int) -> void:
		cfg.set_value("player", "spawn_point", &"" if index == 0 else StringName(points.get_item_text(index)))
		mark_edited())
	add_child(points)

	add_child(dim_label("Posición del player"))
	var has_position := cfg.has_section_key("player", "position")
	var saved_position: Vector3 = cfg.get_value("player", "position", Vector3.ZERO)
	var axes := HBoxContainer.new()
	for axis in 3:
		var spin := SpinBox.new()
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.step = 0.01
		spin.prefix = "xyz"[axis]
		spin.value = saved_position[axis]
		spin.editable = has_position
		spin.size_flags_horizontal = SIZE_EXPAND_FILL
		spin.value_changed.connect(func(value: float) -> void:
			var p: Vector3 = cfg.get_value("player", "position", Vector3.ZERO)
			p[axis] = value
			cfg.set_value("player", "position", p)
			mark_edited())
		axes.add_child(spin)
	add_child(axes)
	var toggle := CheckBox.new()
	toggle.text = "Guardar posición (si no, aparece donde lo pone la escena)"
	toggle.button_pressed = has_position
	toggle.toggled.connect(func(on: bool) -> void:
		set_or_erase("player", "position", saved_position if on else null, null)
		mark_edited()
		refresh())
	add_child(toggle)


## Los id de los SpawnPoint escritos en la escena (no los de escenas instanciadas adentro).
func _spawn_ids(scene: String) -> PackedStringArray:
	var ids := PackedStringArray()
	if scene.is_empty() or not FileAccess.file_exists(scene):
		return ids
	var sources: Array[String] = []
	var uses_source := func(line: String) -> bool:
		return sources.any(func(source: String) -> bool: return 'ExtResource("%s")' % source in line)
	var point_id := ""
	for line in FileAccess.get_file_as_string(scene).split("\n"):
		if line.begins_with("[ext_resource") and SPAWN_SOURCES.any(func(path: String) -> bool: return 'path="%s"' % path in line):
			sources.append(line.get_slice(' id="', 1).get_slice('"', 0))
		elif line.begins_with("["):
			if not point_id.is_empty() and not ids.has(point_id):
				ids.append(point_id)
			point_id = "start" if line.begins_with("[node ") and uses_source.call(line) else ""
		elif line.begins_with("script = ExtResource(") and uses_source.call(line):
			point_id = "start"
		elif not point_id.is_empty() and line.begins_with('id = &"'):
			point_id = line.get_slice('"', 1)
	if not point_id.is_empty() and not ids.has(point_id):
		ids.append(point_id)
	return ids


func _set_health(health: int) -> void:
	cfg.set_value("player", "max_health", health)
	mark_edited()
	refresh()
