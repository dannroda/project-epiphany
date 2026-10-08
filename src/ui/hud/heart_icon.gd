class_name HeartIcon
extends Control
## Un corazón con 0..4 cuartos: el lleno se recorta de izquierda a derecha.

const SIZE := Vector2(30, 28)
const EMPTY := preload("res://assets/ui/heart_empty.svg")
const FULL := preload("res://assets/ui/heart_full.svg")

var quarters := 0:
	set(value):
		quarters = clampi(value, 0, 4)
		_layout()

var icon_size := SIZE:
	set(value):
		icon_size = value
		_layout()

var _clip := Control.new()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_texture(EMPTY))
	_clip.clip_contents = true
	_clip.mouse_filter = MOUSE_FILTER_IGNORE
	_clip.add_child(_texture(FULL))
	add_child(_clip)
	_layout()


func _layout() -> void:
	custom_minimum_size = icon_size
	pivot_offset = icon_size / 2.0
	get_child(0).size = icon_size
	_clip.get_child(0).size = icon_size
	_clip.size = Vector2(icon_size.x * quarters / 4.0, icon_size.y)


func _texture(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture = texture
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	return rect
