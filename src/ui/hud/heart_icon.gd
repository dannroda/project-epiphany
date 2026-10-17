class_name HeartIcon
extends Control
## Un corazón con 0..4 cuartos, que se llenan en sentido antihorario desde arriba a la izquierda (se pierde primero el de arriba a la derecha).

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
@onready var quarter_nodes: Array[Control] = [$TopLeft, $BottomLeft, $BottomRight, $TopRight]


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
	var half := icon_size / 2.0
	for i in quarter_nodes.size():
		var corner := Vector2(half.x if i >= 2 else 0.0, half.y if i in [1, 2] else 0.0)
		var quarter := quarter_nodes[i]
		quarter.position = corner
		quarter.size = half
		quarter.visible = i < quarters
		var full := quarter.get_node(^"Full") as TextureRect
		full.position = -corner
		full.size = icon_size


func pop() -> void:
	var player := $Pop as AnimationPlayer
	player.stop()
	player.play(&"pop")
