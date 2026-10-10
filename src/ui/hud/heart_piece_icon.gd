class_name HeartPieceIcon
extends Control
## Corazón partido en cuartos: se llenan en sentido horario desde arriba a la izquierda.

var pieces := 0:
	set(value):
		pieces = clampi(value, 0, 4)
		if is_node_ready():
			_layout()

@onready var quarters: Array[Control] = [$TopLeft, $TopRight, $BottomRight, $BottomLeft]


func _ready() -> void:
	_layout()


func _layout() -> void:
	for i in quarters.size():
		quarters[i].visible = i < pieces
