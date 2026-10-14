class_name HeartIcon
extends Control
## Un corazón con 0..4 cuartos: el lleno se recorta de izquierda a derecha.

const SIZE := Vector2(30, 28)
const SCENE_PATH := "res://src/ui/hud/heart_icon.tscn"

var quarters := 0:
	set(value):
		quarters = clampi(value, 0, 4)
		_layout()

var icon_size := SIZE:
	set(value):
		icon_size = value
		_layout()

@onready var empty: TextureRect = $Empty
@onready var clip: Control = $Clip
@onready var full: TextureRect = $Clip/Full


static func create(filled := 0, heart_size := SIZE) -> HeartIcon:
	var heart: HeartIcon = load(SCENE_PATH).instantiate()
	heart.icon_size = heart_size
	heart.quarters = filled
	return heart


func _ready() -> void:
	_layout()


func _layout() -> void:
	custom_minimum_size = icon_size
	pivot_offset = icon_size / 2.0
	if not is_node_ready():
		return
	empty.size = icon_size
	full.size = icon_size
	clip.size = Vector2(icon_size.x * quarters / float(GameState.HP_PER_HEART), icon_size.y)
