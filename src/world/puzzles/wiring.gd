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
## drive: ya se mostró con la cámara la primera vez.
var revealed := false
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


## Lo que se abre con interruptores (Door, Gate): `open(animate)` al cumplirse (la primera vez, con la cámara si su
## `reveal_on_open`), `close()` al dejar de cumplirse si su `stays_open` es false, y sin animar si ya arranca cumplida.
func drive(target: Node3D, open: Callable, close: Callable) -> Wiring:
	changed.connect(func(satisfied: bool) -> void:
		if not is_instance_valid(target):
			return
		if satisfied and target.get(&"reveal_on_open") and not revealed:
			revealed = true
			TopDownCamera.reveal_unlock(target, open)
		elif satisfied:
			open.call()
		elif not target.get(&"stays_open"):
			close.call())
	settled.connect(func(satisfied: bool) -> void:
		if satisfied and is_instance_valid(target):
			open.call(false))
	return self


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
