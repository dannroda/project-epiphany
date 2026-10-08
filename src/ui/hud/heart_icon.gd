class_name HeartIcon
extends Control
## Un corazón con 0..4 cuartos: el lleno se recorta de izquierda a derecha.

const SIZE := Vector2(30, 28)
const EMPTY := preload("res://assets/ui/heart_empty.svg")
const FULL := preload("res://assets/ui/heart_full.svg")

var quarters := 0:
	set(value):
		quarters = clampi(value, 0, 4)
		if is_node_ready():
			_clip.size.x = SIZE.x * quarters / 4.0

var _clip := Control.new()


func _init() -> void:
	custom_minimum_size = SIZE
	pivot_offset = SIZE / 2.0
	mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_texture(EMPTY))
	_clip.clip_contents = true
	_clip.size = Vector2(0, SIZE.y)
	_clip.mouse_filter = MOUSE_FILTER_IGNORE
	_clip.add_child(_texture(FULL))
	add_child(_clip)


func _ready() -> void:
	quarters = quarters


func _texture(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture = texture
	rect.size = SIZE
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	return rect
