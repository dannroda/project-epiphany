class_name BowModel
extends EquippedItem
## El arco en la mano: `draw` (0..1) tensa la cuerda (shape key "tensado") y lleva la flecha con ella.

## Centro de la cuerda en x (espacio del arco), sin tensar y a fondo.
const STRING_REST := -0.2
const STRING_DRAWN := -0.58

@export var draw := 0.0:
	set(value):
		draw = clampf(value, 0.0, 1.0)
		if is_node_ready():
			_apply()
@export var nocked := false:
	set(value):
		nocked = value
		if is_node_ready():
			_apply()

@onready var model: MeshInstance3D = $Model
@onready var arrow: Node3D = $Arrow


func _ready() -> void:
	_apply()


func _apply() -> void:
	model.set_blend_shape_value(0, draw)
	arrow.visible = nocked
	arrow.position.x = lerpf(STRING_REST, STRING_DRAWN, draw)
