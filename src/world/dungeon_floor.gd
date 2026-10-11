class_name DungeonFloor
extends Node3D
## Un piso de una mazmorra de varios pisos: su GridMap, sus salas y lo que hay en él. Los pisos van a HEIGHT de
## distancia; la cámara oculta los que quedan arriba del player.

const GROUP := &"dungeon_floors"
const HEIGHT := 8.0
## Cuánto por debajo de su piso sigue contando una sala (el que cae por un hueco pasa a la de abajo).
const BELOW := 2.5

## 0 = planta baja, 1 = el de arriba, -1 = el sótano.
@export var level := 0
@export var display_name: String = ""


func _ready() -> void:
	add_to_group(GROUP)


## Cómo lo nombran el mapa y el minimapa: 1P, 2P… y S1, S2… los sótanos.
func code() -> String:
	return "%dP" % (level + 1) if level >= 0 else "S%d" % -level


static func of(node: Node) -> DungeonFloor:
	var parent := node.get_parent()
	while parent and not parent is DungeonFloor:
		parent = parent.get_parent()
	return parent as DungeonFloor


static func show_up_to(tree: SceneTree, level: int) -> void:
	for node in tree.get_nodes_in_group(GROUP):
		(node as DungeonFloor).visible = (node as DungeonFloor).level <= level
