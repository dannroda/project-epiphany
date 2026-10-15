class_name PackTurns
## Turnos de una jauría (atoq, 11.196): de a uno por objetivo se tira a morder; los demás lo rodean.

static var _holders: Dictionary[int, Node] = {}


static func claim(target: Node, agent: Node) -> bool:
	var holder: Node = _holders.get(target.get_instance_id())
	if is_instance_valid(holder) and holder != agent and not (holder is Enemy and holder.is_dead):
		return false
	_holders[target.get_instance_id()] = agent
	return true


static func release(target: Node, agent: Node) -> void:
	if target and _holders.get(target.get_instance_id()) == agent:
		_holders.erase(target.get_instance_id())
