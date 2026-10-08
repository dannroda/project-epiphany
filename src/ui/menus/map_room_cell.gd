class_name MapRoomCell
extends Control
## Una sala en la pantalla de mapa, dibujada como en el mockup: visitada, sin visitar (borde punteado) o actual.

enum State { VISITED, MAPPED, CURRENT }

const SIZE := Vector2(124, 88)
const FILL := Color("#3a4250")
const BORDER := Color("#56627a")
const GOLD := Color("#d9a441")
const GREY := Color("#6b7280")
const BOSS := Color("#e0786c")
const NAME := Color("#cfd3dc")

var state: State = State.VISITED
var room_name := ""
var closed_chests := 0
var opened_chests := 0
var boss := false
var here := false
## Hacia dónde mira el player (radianes en pantalla, 0 = arriba).
var facing := 0.0


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	match state:
		State.VISITED:
			draw_box(self, rect, FILL, BORDER, 2, 8)
		State.CURRENT:
			draw_box(self, rect, FILL, GOLD, 3, 8)
		State.MAPPED:
			draw_dashed_rect(self, rect.grow(-1), BORDER)
	var font := get_theme_default_font()
	draw_string(font, Vector2(8, 20), room_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 13, NAME)
	var x := size.x - 12.0
	var y := size.y - 14.0
	if here:
		draw_arrow(self, Vector2(x - 2, y - 2), facing)
		x -= 26
	if boss:
		draw_eye(self, Vector2(x - 4, y))
		x -= 30
	for i in closed_chests:
		draw_chest(self, Vector2(x - 6, y), GOLD)
		x -= 24
	for i in opened_chests:
		draw_chest(self, Vector2(x - 6, y), GREY)
		x -= 24


static func draw_box(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, width: int, radius: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	canvas.draw_style_box(box, rect)


static func draw_dashed_rect(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		canvas.draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 2.0, 6.0)


static func draw_chest(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	canvas.draw_rect(Rect2(center + Vector2(-9, -4), Vector2(18, 11)), color, false, 1.8)
	canvas.draw_arc(center + Vector2(0, -4), 9.0, PI, TAU, 10, color, 1.8)
	canvas.draw_line(center + Vector2(-9, 0), center + Vector2(9, 0), color, 1.5)


static func draw_eye(canvas: CanvasItem, center: Vector2) -> void:
	var points := PackedVector2Array()
	for i in 17:
		var t := TAU * i / 16.0
		points.append(center + Vector2(cos(t) * 11.0, sin(t) * 6.0))
	canvas.draw_polyline(points, BOSS, 1.8, true)
	canvas.draw_circle(center, 3.0, BOSS, false, 1.8)


## Flecha del player; `angle` en radianes de pantalla (0 = arriba).
static func draw_arrow(canvas: CanvasItem, center: Vector2, angle: float) -> void:
	var points := PackedVector2Array([Vector2(0, -8), Vector2(7, 7), Vector2(0, 3), Vector2(-7, 7)])
	for i in points.size():
		points[i] = center + points[i].rotated(angle)
	canvas.draw_colored_polygon(points, GOLD)
