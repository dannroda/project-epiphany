extends PanelContainer
## Panel de detalle de un ítem: ícono, nombre, tipo, descripción y stats.

@onready var icon: TextureRect = %DetailIcon
@onready var title: Label = %DetailName
@onready var kind: Label = %DetailKind
@onready var text: Label = %DetailText
@onready var stats_top: HSeparator = %StatsTop
@onready var stats: VBoxContainer = %DetailStats
@onready var actions: HBoxContainer = %DetailActions


func show_item(texture: Texture2D, name_text: String, kind_text: String, description: String) -> void:
	for child in stats.get_children():
		stats.remove_child(child)
		child.queue_free()
	stats_top.visible = false
	icon.texture = texture
	title.text = name_text
	kind.text = kind_text
	text.text = description


func add_stat(label: String, value: String) -> void:
	stats_top.visible = true
	stats.add_child(StatRow.create(label, value))
