class_name MapFloorButton
extends Button
## Un piso en la columna de pisos del mapa de mazmorra: código, nombre y marcas (estás acá, cofres, jefe).

const SCENE_PATH := "res://src/ui/menus/map_floor_button.tscn"

@export var normal_style: StyleBox
@export var selected_style: StyleBox
@export var code_font: Font

var code := ""
var floor_name := ""
var level := 0
var selected := false
var here := false
var chest := false
var boss := false


static func create() -> MapFloorButton:
	return load(SCENE_PATH).instantiate()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var style := selected_style if selected else normal_style
	if style:
		draw_style_box(style, rect)
	draw_string(code_font, Vector2(14, 36), code, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, MapRoomCell.GOLD if selected else MapRoomCell.TEXT)
	var code_width := code_font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(get_theme_default_font(), Vector2(22 + code_width, 35), tr(floor_name), HORIZONTAL_ALIGNMENT_LEFT, size.x - code_width - 30, 14, MapRoomCell.NAME)
	var x := 22.0
	var y := size.y - 20.0
	if here:
		MapRoomCell.draw_arrow(self, Vector2(x, y), 0.0)
		x += 26
	if chest:
		MapRoomCell.draw_chest(self, Vector2(x + 2, y), MapRoomCell.GOLD)
		x += 28
	if boss:
		MapRoomCell.draw_eye(self, Vector2(x + 4, y))
