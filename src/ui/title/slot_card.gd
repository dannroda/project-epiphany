class_name SlotCard
extends Button
## Una ranura en la pantalla de partidas (mockup FileSelect): número, corazones, ubicación, ítems y tiempo jugado.

const GOLD := Color("#d9a441")
const BORDER := Color("#3a4250")
const PANEL := Color("#151920")
const MUTED := Color("#a79f8e")
const DIM := Color("#6f6a60")

var slot := 0
var summary := {}


func _init(slot_index: int, data: Dictionary) -> void:
	slot = slot_index
	summary = data
	focus_mode = FOCUS_ALL
	custom_minimum_size = Vector2(0, 120 if not data.is_empty() else 92)
	var empty := StyleBoxEmpty.new()
	for style in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(style, empty)
	focus_entered.connect(_on_focus)
	focus_exited.connect(_on_focus)
	mouse_entered.connect(grab_focus)


func _ready() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	row.offset_left = 28
	row.offset_right = -28
	row.add_theme_constant_override(&"separation", 28)
	add_child(row)
	var number := _label(str(slot + 1), 40, &"Title")
	number.custom_minimum_size.x = 40
	number.add_theme_color_override(&"font_color", DIM if summary.is_empty() else MUTED)
	number.name = "Number"
	row.add_child(number)
	if summary.is_empty():
		var plus := _label("+", 30, &"")
		plus.add_theme_color_override(&"font_color", MUTED)
		row.add_child(plus)
		var text := _label("Nueva partida", 22, &"")
		text.add_theme_color_override(&"font_color", MUTED)
		row.add_child(text)
		return
	var middle := VBoxContainer.new()
	middle.mouse_filter = MOUSE_FILTER_IGNORE
	middle.size_flags_horizontal = SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override(&"separation", 10)
	row.add_child(middle)
	var hearts := HBoxContainer.new()
	hearts.mouse_filter = MOUSE_FILTER_IGNORE
	hearts.add_theme_constant_override(&"separation", 4)
	for i in int(summary.max_health) / 4:
		var heart := HeartIcon.new()
		heart.quarters = 4
		heart.custom_minimum_size = HeartIcon.SIZE
		hearts.add_child(heart)
	middle.add_child(hearts)
	middle.add_child(_label(summary.location if not String(summary.location).is_empty() else "—", 22, &""))
	var items := HBoxContainer.new()
	items.mouse_filter = MOUSE_FILTER_IGNORE
	items.add_theme_constant_override(&"separation", 12)
	for id in summary.items:
		var item := Items.get_item(id)
		if item == null or item.icon == null:
			continue
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		items.add_child(icon)
	row.add_child(items)
	var time := _label(format_time(summary.play_time), 20, &"")
	time.add_theme_color_override(&"font_color", MUTED)
	time.custom_minimum_size.x = 90
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(time)


static func format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	return "%02d:%02d" % [minutes / 60, minutes % 60]


func _label(text: String, size: int, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.add_theme_font_size_override(&"font_size", size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = SIZE_SHRINK_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label


func _on_focus() -> void:
	var number := find_child("Number", true, false) as Label
	if number:
		number.add_theme_color_override(&"font_color", GOLD if has_focus() else (DIM if summary.is_empty() else MUTED))
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if summary.is_empty():
		var color := GOLD if has_focus() else BORDER
		MapRoomCell.draw_dashed_rect(self, rect.grow(-1), color)
		return
	draw_style_box(_box(GOLD if has_focus() else BORDER, 3 if has_focus() else 2), rect)


func _box(border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(14)
	return box
