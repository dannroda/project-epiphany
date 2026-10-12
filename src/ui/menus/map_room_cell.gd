class_name MapRoomCell
extends Control
## Una sala en la pantalla de mapa con los marcos de la UI: visitada, sin visitar (marco vacío) o actual.

enum State { VISITED, MAPPED, CURRENT }

const SIZE := Vector2(124, 88)
const BORDER := Color("#56627a")
const GOLD := Color("#d9a441")
const GREY := Color("#6b7280")
const BOSS := Color("#e0786c")
const NAME := Color("#cfd3dc")
const TEXT := Color("#efe6d2")
const DOOR := Color("#6b5a3a")
const SEALED := Color("#8a8374")
const PAPER := Color("#cdb98f")
const PAPER_INK := Color("#6b4f30")
const INK := Color("#0b0d10")
const PORTAL := Color("#7fd3dd")
const SCENE_PATH := "res://src/ui/menus/map_room_cell.tscn"

@export var visited_style: StyleBox
@export var mapped_style: StyleBox
@export var current_style: StyleBox

var state: State = State.VISITED
var room_name := ""
var closed_chests := 0
var opened_chests := 0
var boss := false
var here := false
## Hacia dónde mira el player (radianes en pantalla, 0 = arriba).
var facing := 0.0


static func create() -> MapRoomCell:
	return load(SCENE_PATH).instantiate()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var style: StyleBox = [visited_style, mapped_style, current_style][state]
	if style:
		draw_style_box(style, rect)
	var font := get_theme_default_font()
	draw_string(font, Vector2(10, 22), tr(room_name), HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 13, NAME)
	var x := size.x - 14.0
	var y := size.y - 16.0
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


static func draw_entrance(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	canvas.draw_polyline(_arch(center, Vector2(8, 8), 9.0), color, 1.8, true)
	canvas.draw_polyline(_arch(center + Vector2(0, 4), Vector2(3, 3), 5.0), color, 1.8, true)


## Portal de viaje (mockup Pause_Map_Travel): óvalo oscuro con borde y centro celestes y una base.
static func draw_portal(canvas: CanvasItem, center: Vector2, scale := 1.0) -> void:
	var outer := _ellipse(center, Vector2(9, 11) * scale)
	canvas.draw_colored_polygon(outer, INK)
	canvas.draw_polyline(outer + PackedVector2Array([outer[0]]), PORTAL, 2.4 * scale, true)
	canvas.draw_colored_polygon(_ellipse(center, Vector2(4.5, 6) * scale), Color(PORTAL, 0.85))
	canvas.draw_line(center + Vector2(-9, 10) * scale, center + Vector2(9, 10) * scale, PORTAL, 2.4 * scale, true)


static func _ellipse(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * i / 24.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func draw_cave(canvas: CanvasItem, center: Vector2) -> void:
	var mound := _arch(center + Vector2(0, -2), Vector2(10, 8), 7.0)
	canvas.draw_colored_polygon(mound.slice(0, -1), DOOR)
	canvas.draw_polyline(mound, TEXT, 1.4, true)
	canvas.draw_colored_polygon(_arch(center + Vector2(0, 2), Vector2(4.5, 4), 3.0).slice(0, -1), INK)


static func draw_tablet(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	canvas.draw_polyline(_arch(center + Vector2(0, -4), Vector2(6, 3), 13.0), color, 1.8, true)
	for y in [-1.0, 2.0, 5.0]:
		canvas.draw_line(center + Vector2(-3, y), center + Vector2(3 if y < 5.0 else 1, y), color, 1.5)


## Contorno de arco de medio punto: base en `center.y + depth`, semieje `radii`.
static func _arch(center: Vector2, radii: Vector2, depth: float) -> PackedVector2Array:
	var points := PackedVector2Array([center + Vector2(-radii.x, depth)])
	for i in 13:
		var angle := PI + PI * i / 12.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	points.append(center + Vector2(radii.x, depth))
	points.append(center + Vector2(-radii.x, depth))
	return points


static func draw_pin(canvas: CanvasItem, center: Vector2) -> void:
	var points := PackedVector2Array([center + Vector2(0, -10), center + Vector2(8, -2), center + Vector2(0, 10), center + Vector2(-8, -2)])
	canvas.draw_colored_polygon(points, GOLD)
	points.append(points[0])
	canvas.draw_polyline(points, INK, 1.6, true)
	canvas.draw_circle(center + Vector2(0, -2), 2.6, INK)


static func draw_lock(canvas: CanvasItem, center: Vector2, color: Color) -> void:
	canvas.draw_rect(Rect2(center + Vector2(-3, -0.5), Vector2(6, 4)), color, false, 1.4)
	canvas.draw_arc(center + Vector2(0, -0.5), 2.0, PI, TAU, 8, color, 1.4)


static func draw_fog(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, PAPER)
	canvas.draw_rect(rect.grow(-0.5), PAPER_INK, false, 1.0)
	canvas.draw_line(rect.position + Vector2(5, rect.size.y - 5), rect.position + Vector2(rect.size.x * 0.5, 6), PAPER_INK, 1.0)
