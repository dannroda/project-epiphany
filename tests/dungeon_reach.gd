extends RefCounted
## Alcanzabilidad de una mazmorra: junta su DungeonGraph con lo que dice la escena y recorre todos los estados
## (zona, ítems y flags, llaves en mano, puertas abiertas con llave). Falla si falta algo en el grafo o si hay un
## estado alcanzable desde el que ya no se llega al objetivo.

const COVERED := [&"Door", &"Gate", &"Bridge", &"CrackedWall", &"Chest", &"EyeSwitch", &"FloorSwitch", &"LightReceiver", &"WaveSpawner", &"ArenaFight"]
const MAX_STATES := 200000


## Lee el grafo y la escena (sin escena, solo el grafo). Devuelve {problems, model}; `model` es lo que recorre `search`.
static func read(graph: DungeonGraph) -> Dictionary:
	if graph.scene.is_empty():
		return _read_design(graph)
	var problems := PackedStringArray()
	var root := (load(graph.scene) as PackedScene).instantiate()
	var model := {start = graph.start, goal = graph.goal, links = [], spots = []}
	var areas := {}
	var referenced := {}
	for link in graph.links:
		areas[link.from] = true
		areas[link.to] = true
		var entry := {from = link.from, to = link.to, one_way = link.one_way, needs = _clauses(link.needs), key_door = "", label = "%s → %s" % [link.from, link.to]}
		for path in link.through:
			var node := root.get_node_or_null(path)
			if node == null:
				problems.append("%s: no existe %s en la escena" % [entry.label, path])
				continue
			referenced[node] = true
			entry.label += " (%s)" % node.name
			if node is Door and node.kind == Door.Kind.LOCKED:
				entry.key_door = str(path)
			else:
				entry.needs.append_array(_lock(node, problems))
		if link.locked != not entry.key_door.is_empty():
			problems.append("%s: el grafo dice %s y la escena no" % [entry.label, "puerta con llave" if link.locked else "sin llave"])
		model.links.append(entry)
	for i in graph.spots.size():
		var spot := graph.spots[i]
		areas[spot.area] = true
		var node := root.get_node_or_null(spot.node)
		if node == null:
			problems.append("%s: no existe %s en la escena" % [spot.area, spot.node])
			continue
		referenced[node] = true
		var entry := {area = spot.area, needs = _clauses(spot.needs), gives = ["spot:%d" % i], key = false, label = "%s en %s" % [node.name, spot.area]}
		for path in spot.through:
			var gate := root.get_node_or_null(path)
			if gate == null:
				problems.append("%s: no existe %s en la escena" % [entry.label, path])
				continue
			referenced[gate] = true
			entry.needs.append_array(_lock(gate, problems))
		if node is Chest and not node.switches.is_empty():
			entry.needs.append_array(_wiring(node, problems))
		if node is Chest:
			if node.item.id == &"small_key":
				entry.key = true
			else:
				entry.gives.append(String(node.item.id))
		if spot.key != entry.key:
			problems.append("%s: el grafo dice %s y la escena no" % [entry.label, "llave chica" if spot.key else "sin llave chica"])
		var token := _token(node)
		if not token.is_empty():
			entry.gives.append(token)
		if not spot.gives.is_empty():
			entry.gives.append(String(spot.gives))
		model.spots.append(entry)
	problems.append_array(_coverage(root, areas, referenced))
	problems.append_array(_tokens(graph, model))
	root.free()
	return {problems = problems, model = model}


static func _read_design(graph: DungeonGraph) -> Dictionary:
	var model := {start = graph.start, goal = graph.goal, links = [], spots = []}
	for i in graph.links.size():
		var link := graph.links[i]
		model.links.append({from = link.from, to = link.to, one_way = link.one_way, needs = _clauses(link.needs), key_door = "puerta %d" % i if link.locked else "", label = "%s → %s" % [link.from, link.to]})
	for i in graph.spots.size():
		var spot := graph.spots[i]
		var gives := ["spot:%d" % i]
		if not spot.gives.is_empty():
			gives.append(String(spot.gives))
		model.spots.append({area = spot.area, needs = _clauses(spot.needs), gives = gives, key = spot.key, label = "%s en %s" % [spot.node, spot.area]})
	return {problems = _tokens(graph, model), model = model}


## Las reglas del molde (11.113): sin el ítem no se llega al objetivo; el ítem pide vencer al sub-jefe, que se vence sin él.
static func rules(graph: DungeonGraph, model: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var item := String(graph.item)
	var guard := String(graph.guard)
	if not item.is_empty() and reaches(model, graph.brings, String(graph.goal), [item]):
		problems.append("se llega a %s sin %s" % [graph.goal, item])
	if not guard.is_empty():
		if not item.is_empty() and not reaches(model, graph.brings, guard, [item]):
			problems.append("%s pide %s" % [guard, item])
		if not item.is_empty() and reaches(model, graph.brings, item, [guard]):
			problems.append("%s se consigue sin %s" % [item, guard])
	return problems


## Si algún orden de juego consigue `token` cuando nadie da lo que está en `banned`.
static func reaches(model: Dictionary, brings: Array, token: String, banned: Array = []) -> bool:
	var first := {area = model.start, have = {}, keys = 0, opened = {}}
	for item in brings:
		first.have[String(item)] = true
	var seen := {_key(first): true}
	var queue := [first]
	while not queue.is_empty():
		var state: Dictionary = queue.pop_front()
		if state.have.has(token):
			return true
		for next in _moves(model, state, banned):
			var next_key := _key(next.state)
			if not seen.has(next_key) and seen.size() < MAX_STATES:
				seen[next_key] = true
				queue.append(next.state)
	return false


## Recorre todos los estados. Devuelve los problemas: objetivo inalcanzable o estados sin salida (con el camino).
static func search(model: Dictionary, brings: Array = []) -> PackedStringArray:
	var first := {area = model.start, have = {}, keys = 0, opened = {}}
	for item in brings:
		first.have[String(item)] = true
	var start_key := _key(first)
	var states := {start_key: first}
	var parent := {start_key: ["", ""]}
	var edges := {}
	var queue := [start_key]
	var goals := []
	while not queue.is_empty():
		var key: String = queue.pop_front()
		var state: Dictionary = states[key]
		if state.have.has(String(model.goal)):
			goals.append(key)
			continue
		edges[key] = []
		for next in _moves(model, state):
			var next_key := _key(next.state)
			edges[key].append(next_key)
			if not states.has(next_key):
				if states.size() >= MAX_STATES:
					return PackedStringArray(["más de %d estados: el grafo es demasiado grande" % MAX_STATES])
				states[next_key] = next.state
				parent[next_key] = [key, next.label]
				queue.append(next_key)
	if goals.is_empty():
		return PackedStringArray(["no se llega a %s" % model.goal])
	var reaches := {}
	for key in goals:
		reaches[key] = true
	var changed := true
	while changed:
		changed = false
		for key in edges:
			if reaches.has(key):
				continue
			for next in edges[key]:
				if reaches.has(next):
					reaches[key] = true
					changed = true
					break
	for key in states:
		if not reaches.has(key):
			return PackedStringArray(["sin salida: %s" % " · ".join(_path(parent, key))])
	return PackedStringArray()


static func _moves(model: Dictionary, state: Dictionary, banned: Array = []) -> Array:
	var moves := []
	for link in model.links:
		var forward: bool = link.from == state.area
		var backward: bool = link.to == state.area and not link.one_way
		if not (forward or backward) or not _met(link.needs, state.have):
			continue
		var next := _copy(state)
		next.area = link.to if forward else link.from
		var label: String = link.label if forward else "%s → %s" % [link.to, link.from]
		if not link.key_door.is_empty() and not state.opened.has(link.key_door):
			if state.keys == 0:
				continue
			next.keys -= 1
			next.opened[link.key_door] = true
			label += " gastando una llave"
		moves.append({state = next, label = label})
	for spot in model.spots:
		if spot.area != state.area or state.have.has(spot.gives[0]) or not _met(spot.needs, state.have):
			continue
		if banned.any(func(token: String) -> bool: return spot.gives.has(token)):
			continue
		var next := _copy(state)
		for token in spot.gives:
			next.have[token] = true
		if spot.key:
			next.keys += 1
		moves.append({state = next, label = spot.label})
	return moves


static func _met(clauses: Array, have: Dictionary) -> bool:
	for clause in clauses:
		if not clause.any(func(token: String) -> bool: return have.has(token)):
			return false
	return true


static func _copy(state: Dictionary) -> Dictionary:
	return {area = state.area, have = state.have.duplicate(), keys = state.keys, opened = state.opened.duplicate()}


static func _key(state: Dictionary) -> String:
	var have: Array = state.have.keys()
	have.sort()
	var opened: Array = state.opened.keys()
	opened.sort()
	return "%s|%s|%d|%s" % [state.area, ",".join(have), state.keys, ",".join(opened)]


static func _path(parent: Dictionary, key: String) -> PackedStringArray:
	var steps := PackedStringArray()
	while not parent[key][0].is_empty():
		steps.append(parent[key][1])
		key = parent[key][0]
	steps.reverse()
	return steps


## `["a|b", "c"]` → `[["a", "b"], ["c"]]`: hace falta uno de cada grupo.
static func _clauses(needs: Array) -> Array:
	return needs.map(func(need: StringName) -> Array: return Array(String(need).split("|")))


static func _lock(node: Node, problems: PackedStringArray) -> Array:
	if node is Door:
		match node.kind:
			Door.Kind.BOSS:
				return [["boss_key"]]
			Door.Kind.SWITCH:
				return _wiring(node, problems)
		return []
	if node is Gate or node is Bridge:
		return _wiring(node, problems)
	if node is CrackedWall:
		return _wiring(node, problems) if not node.switches.is_empty() else [["bomb_bag"]]
	return []


static func _wiring(node: Node, problems: PackedStringArray) -> Array:
	var tokens := []
	for path: NodePath in node.switches:
		var source := node.get_node_or_null(path)
		if source == null:
			problems.append("%s: no existe su interruptor %s" % [node.name, path])
		else:
			tokens.append(_token(source))
	if tokens.is_empty():
		problems.append("%s no tiene interruptores" % node.name)
		return [["nunca"]]
	if node.get("condition") == Wiring.Condition.ANY:
		return [tokens]
	return tokens.map(func(token: String) -> Array: return [token])


static func _token(node: Node) -> String:
	var flag: Variant = node.get(&"flag")
	if flag is StringName and not flag.is_empty() and not node is Door:
		return String(flag)
	return "" if node is Chest or node is Door else "node:%s" % node.name


static func _coverage(root: Node, areas: Dictionary, referenced: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var rooms := {}
	for node in root.find_children("*", "", true, true):
		if node.owner != root:
			continue
		if node is Room:
			rooms[node.name] = true
		var type := _covered_type(node)
		if not type.is_empty() and not referenced.has(node):
			problems.append("%s (%s) no está en el grafo" % [node.name, type])
	for room in rooms:
		if not areas.keys().any(func(area: StringName) -> bool: return String(area).get_slice(":", 0) == room):
			problems.append("la sala %s no está en el grafo" % room)
	for area in areas:
		if not rooms.has(StringName(String(area).get_slice(":", 0))):
			problems.append("la zona %s no es una sala de la escena" % area)
	return problems


static func _covered_type(node: Node) -> StringName:
	var script: Script = node.get_script()
	while script != null:
		if COVERED.has(script.get_global_name()):
			return script.get_global_name()
		script = script.get_base_script()
	return &""


static func _tokens(graph: DungeonGraph, model: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var given := {}
	for item in graph.brings:
		given[String(item)] = true
	for spot in model.spots:
		for token in spot.gives:
			given[token] = true
		if spot.key:
			given["small_key"] = true
	if not given.has(String(graph.goal)):
		problems.append("nadie da %s" % graph.goal)
	var needed := []
	for entry in model.links + model.spots:
		for clause in entry.needs:
			if not clause.any(func(token: String) -> bool: return given.has(token)):
				needed.append("%s pide %s y nadie lo da" % [entry.label, "|".join(clause)])
	for text in needed:
		if not problems.has(text):
			problems.append(text)
	return problems
