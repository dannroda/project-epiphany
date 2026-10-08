extends PanelContainer
## Panel de detalle de un ítem: ícono, nombre, tipo, descripción y stats.

@onready var icon: TextureRect = %DetailIcon
@onready var title: Label = %DetailName
@onready var kind: Label = %DetailKind
@onready var text: Label = %DetailText
@onready var stats: VBoxContainer = %DetailStats


func show_item(texture: Texture2D, name_text: String, kind_text: String, description: String) -> void:
	for child in stats.get_children():
		child.queue_free()
	icon.texture = texture
	title.text = name_text
	kind.text = kind_text
	text.text = description


func add_stat(label: String, value: String) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.theme_type_variation = &"Hint"
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label := Label.new()
	value_label.text = value
	row.add_child(value_label)
	stats.add_child(row)
