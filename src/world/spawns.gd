class_name Spawns
extends RefCounted
## Dónde cuelga lo que aparece en runtime (proyectiles, bombas, pickups, efectos): el nodo del grupo `spawn_root` del
## nivel o, si no tiene, la escena actual. Un solo lugar para el MultiplayerSpawner (M14).

const GROUP := &"spawn_root"


static func root(from: Node) -> Node:
	var tree := from.get_tree()
	var node := tree.get_first_node_in_group(GROUP)
	return node if node else tree.current_scene
