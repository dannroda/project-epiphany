class_name Wiring
extends RefCounted
## Cableado sin código por sala: una lista de interruptores (cualquier nodo con `active` y las señales
## `activated`/`deactivated`: FloorSwitch, EyeSwitch, LightReceiver…) y una condición.

## true cuando la condición pasa a cumplirse; false cuando deja de cumplirse.
signal changed(satisfied: bool)
## Una vez, al frame siguiente de crearse: el estado inicial, cuando todos los interruptores ya leyeron su flag
## (en la escena pueden estar después del que los escucha).
signal settled(satisfied: bool)

enum Condition { ALL, ANY }

var switches: Array[Node] = []
var condition: Condition = Condition.ALL
var _satisfied := false


static func create(owner: Node, paths: Array[NodePath], when: Condition) -> Wiring:
	var wiring := Wiring.new()
	wiring.condition = when
	for path in paths:
		var node := owner.get_node_or_null(path)
		if node == null:
			push_warning("%s: no existe el interruptor %s" % [owner.name, path])
			continue
		wiring.switches.append(node)
		node.connect(&"activated", wiring._update)
		if node.has_signal(&"deactivated"):
			node.connect(&"deactivated", wiring._update)
	wiring._satisfied = wiring.is_satisfied()
	wiring._settle.call_deferred()
	return wiring


func is_satisfied() -> bool:
	if switches.is_empty():
		return false
	var on := switches.map(func(node: Node) -> bool: return node.get(&"active") == true)
	return not on.has(false) if condition == Condition.ALL else on.has(true)


func _settle() -> void:
	_satisfied = is_satisfied()
	settled.emit(_satisfied)


func _update() -> void:
	var now := is_satisfied()
	if now != _satisfied:
		_satisfied = now
		changed.emit(now)
