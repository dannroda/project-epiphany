class_name StatRow
extends VBoxContainer
## Una fila "nombre ........ valor" con su línea abajo (detalle de ítem, mapa).

const SCENE_PATH := "res://src/ui/menus/stat_row.tscn"


static func create(label: String, value: String, muted := false) -> StatRow:
	var row: StatRow = load(SCENE_PATH).instantiate()
	(row.get_node(^"Padding/Row/Name") as Label).text = label
	var value_label := row.get_node(^"Padding/Row/Value") as Label
	value_label.text = value
	if muted:
		value_label.theme_type_variation = &"ValueMuted"
	return row


func value_text() -> String:
	return (get_node(^"Padding/Row/Value") as Label).text
