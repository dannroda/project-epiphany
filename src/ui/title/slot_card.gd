class_name SlotCard
extends Button
## Una ranura en la pantalla de partidas (mockup FileSelect): número, corazones, ubicación, ítems y tiempo jugado.

@export var slot := 0

var summary := {}

@onready var number: Label = %Number
@onready var filled: Control = %Filled
@onready var empty: Control = %Empty
@onready var hearts: HBoxContainer = %Hearts
@onready var location: Label = %Location
@onready var items: HBoxContainer = %Items
@onready var time: Label = %Time


func _ready() -> void:
	number.text = str(slot + 1)
	focus_entered.connect(_paint)
	focus_exited.connect(_paint)
	mouse_entered.connect(grab_focus)
	show_summary(summary)


## Datos de `SaveManager.slot_summary()`; vacío = ranura libre.
func show_summary(data: Dictionary) -> void:
	summary = data
	if not is_node_ready():
		return
	filled.visible = not data.is_empty()
	empty.visible = data.is_empty()
	time.visible = not data.is_empty()
	custom_minimum_size.y = 92.0 if data.is_empty() else 120.0
	for child in hearts.get_children():
		child.queue_free()
	if not data.is_empty():
		for i in int(data.max_health) / 4:
			hearts.add_child(HeartIcon.create(4))
		location.text = data.location if not String(data.location).is_empty() else "—"
		time.text = format_time(data.play_time)
	var ids: Array = data.get("items", [])
	for i in items.get_child_count():
		var icon := items.get_child(i) as TextureRect
		var item := Items.get_item(ids[i]) if i < ids.size() else null
		icon.texture = item.icon if item else null
		icon.visible = item != null
	_paint()


static func format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	return "%02d:%02d" % [minutes / 60, minutes % 60]


func _paint() -> void:
	theme_type_variation = &"SlotCardEmpty" if summary.is_empty() else &"SlotCard"
	number.theme_type_variation = &"SlotNumberFocused" if has_focus() else &"SlotNumber"
	number.modulate.a = 0.6 if summary.is_empty() and not has_focus() else 1.0
