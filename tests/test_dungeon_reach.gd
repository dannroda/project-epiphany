extends "res://tests/test_case.gd"
## Alcanzabilidad de las mazmorras (11.90): cada DungeonGraph de data/dungeons contra su escena.

const Reach := preload("res://tests/dungeon_reach.gd")
const GRAPHS := "res://data/dungeons"


func test_every_dungeon_graph_matches_its_scene_and_has_no_dead_end() -> void:
	var files := Array(DirAccess.get_files_at(GRAPHS)).filter(func(file: String) -> bool: return file.ends_with(".tres"))
	assert_true(not files.is_empty(), "hay grafos")
	for file: String in files:
		var graph := load(GRAPHS.path_join(file)) as DungeonGraph
		var read := Reach.read(graph)
		assert_eq(read.problems, PackedStringArray(), "%s contra su escena" % file)
		assert_eq(Reach.search(read.model, graph.brings), PackedStringArray(), "%s sin salidas trabadas" % file)
		assert_eq(Reach.rules(graph, read.model), PackedStringArray(), "%s cumple el molde" % file)


func test_a_key_spent_on_the_wrong_door_is_a_dead_end() -> void:
	var model := _model([_link("A", "B", "puerta_b"), _link("A", "C", "puerta_c")], [_key("A"), _spot("C", "fin")])
	var problems := Reach.search(model)
	assert_eq(problems.size(), 1, "un problema")
	assert_true(problems[0].begins_with("sin salida") and problems[0].contains("A → B gastando una llave"), problems[0] if problems else "")


func test_two_keys_for_two_doors_have_no_dead_end() -> void:
	var model := _model([_link("A", "B", "puerta_b"), _link("A", "C", "puerta_c")], [_key("A"), _key("B"), _spot("C", "fin")])
	assert_eq(Reach.search(model), PackedStringArray())


func test_a_drop_with_no_way_back_is_a_dead_end() -> void:
	var drop := _link("A", "B")
	drop.one_way = true
	var model := _model([drop], [_spot("A", "fin", ["pluma"]), _spot("A", "pluma")])
	var problems := Reach.search(model)
	assert_true(not problems.is_empty() and problems[0].begins_with("sin salida"), "la caída sin vuelta traba")


func test_an_item_nobody_gives_never_reaches_the_goal() -> void:
	var model := _model([], [_spot("A", "fin", ["gancho"])])
	assert_eq(Reach.search(model), PackedStringArray(["no se llega a fin"]))


func test_a_design_graph_without_a_scene_is_checked_alone() -> void:
	var graph := DungeonGraph.new()
	graph.start = &"A"
	graph.goal = &"fin"
	graph.links = [_design_link("A", "B", true), _design_link("A", "C", true)]
	graph.spots = [_design_spot("A", "", true), _design_spot("C", "fin")]
	var read := Reach.read(graph)
	assert_eq(read.problems, PackedStringArray(), "sin escena no hay nada que cruzar")
	var problems := Reach.search(read.model)
	assert_true(not problems.is_empty() and problems[0].contains("gastando una llave"), "la llave en la puerta equivocada traba igual")


func test_the_item_must_gate_the_goal_and_sit_behind_the_sub_boss() -> void:
	var graph := DungeonGraph.new()
	graph.start = &"A"
	graph.goal = &"fin"
	graph.item = &"arco"
	graph.guard = &"vigia"
	graph.spots = [_design_spot("A", "vigia"), _design_spot("A", "arco", false, ["vigia"]), _design_spot("A", "fin", false, ["arco"])]
	assert_eq(Reach.rules(graph, Reach.read(graph).model), PackedStringArray(), "el molde bien")
	graph.spots = [_design_spot("A", "vigia", false, ["arco"]), _design_spot("A", "arco"), _design_spot("A", "fin")]
	assert_eq(Reach.rules(graph, Reach.read(graph).model), PackedStringArray(["se llega a fin sin arco", "vigia pide arco", "arco se consigue sin vigia"]))


## 11.176 (la Chullpa se salteaba casi entera): cada llave chica hace falta y la llave del jefe pide volver con el ítem.
func test_optional_keys_and_a_boss_key_before_the_item_break_the_mold() -> void:
	var graph := DungeonGraph.new()
	graph.goal = &"fin"
	graph.item = &"pluma"
	var model := _model([_link("A", "B", "puerta_b")], [_key("A"), _spot("A", "boss_key"), _spot("A", "pluma"), _spot("A", "fin", ["pluma", "boss_key"])])
	assert_eq(Reach.rules(graph, model), PackedStringArray(["se llega a fin sin la llave chica de llave en A", "la llave del jefe se consigue sin pluma (tiene que pedir volver con el ítem)"]))
	model = _model([_link("A", "B", "puerta_b")], [_key("A"), _spot("B", "boss_key", ["pluma"]), _spot("A", "pluma"), _spot("A", "fin", ["pluma", "boss_key"])])
	assert_eq(Reach.rules(graph, model), PackedStringArray(), "la llave abre el camino y la del jefe pide la pluma")


func _design_link(from: String, to: String, locked := false) -> DungeonLink:
	var link := DungeonLink.new()
	link.from = from
	link.to = to
	link.locked = locked
	return link


func _design_spot(area: String, gives: String, key := false, needs: Array[StringName] = []) -> DungeonSpot:
	var spot := DungeonSpot.new()
	spot.area = area
	spot.node = NodePath(gives if gives else "llave")
	spot.gives = gives
	spot.key = key
	spot.needs = needs
	return spot


func _model(links: Array, spots: Array) -> Dictionary:
	for i in spots.size():
		spots[i].gives.push_front("spot:%d" % i)
	return {start = &"A", goal = &"fin", links = links, spots = spots}


func _link(from: String, to: String, key_door := "") -> Dictionary:
	return {from = from, to = to, one_way = false, needs = [], key_door = key_door, label = "%s → %s" % [from, to]}


func _spot(area: String, gives: String, needs := []) -> Dictionary:
	return {area = area, needs = needs.map(func(need: String) -> Array: return [need]), gives = [gives], key = false, label = gives}


func _key(area: String) -> Dictionary:
	return {area = area, needs = [], gives = [], key = true, label = "llave en %s" % area}
