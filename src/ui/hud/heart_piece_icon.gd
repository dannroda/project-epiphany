class_name HeartPieceIcon
extends Control
## Corazón partido en cuartos: se llenan en sentido antihorario desde arriba a la izquierda, como los de vida.

var pieces := 0:
	set(value):
		pieces = clampi(value, 0, 4)
		if is_node_ready():
			_layout()

@onready var quarters: Array[Control] = [$TopLeft, $BottomLeft, $BottomRight, $TopRight]


func _ready() -> void:
	_layout()


func _layout() -> void:
	for i in quarters.size():
		quarters[i].visible = i < pieces
