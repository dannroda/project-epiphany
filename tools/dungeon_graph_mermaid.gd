extends SceneTree
## Diagrama Mermaid de un DungeonGraph, para revisarlo en un documento:
## godot --headless --path . --script res://tools/dungeon_graph_mermaid.gd -- quenoa_graph
## Escribe debug/tmp/<grafo>.mmd y lo imprime. Con escena, las cerraduras salen de la escena.

const Reach := preload("res://tests/dungeon_reach.gd")


func _initialize() -> void:
	var name := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "chullpa_graph"
	var graph := load("res://data/dungeons/%s.tres" % name) as DungeonGraph
	var read := Reach.read(graph)
	var lines := PackedStringArray(["flowchart TD"])
	var ids := {}
	var contents := {}
	for spot: Dictionary in read.model.spots:
		var area := String(spot.area)
		var gives: Array = spot.gives.slice(1)
		if spot.key:
			gives.append("llave chica")
		var text := "%s%s" % [spot.label.get_slice(" en ", 0), (": " + ", ".join(gives)) if not gives.is_empty() else ""]
		if not spot.needs.is_empty():
			text += " ⟵ " + _needs(spot.needs)
		contents[area] = contents.get(area, []) + [text]
	for link: Dictionary in read.model.links:
		for area in [String(link.from), String(link.to)]:
			if not ids.has(area):
				ids[area] = "z%d" % ids.size()
	for area: String in contents:
		if not ids.has(area):
			ids[area] = "z%d" % ids.size()
	for area: String in ids:
		var body := "<b>%s</b>" % area
		for text: String in contents.get(area, []):
			body += "<br/>" + text.replace("\"", "'")
		lines.append("  %s[\"%s\"]" % [ids[area], body])
	for link: Dictionary in read.model.links:
		var tags := []
		if not link.key_door.is_empty():
			tags.append("llave")
		if not link.needs.is_empty():
			tags.append(_needs(link.needs))
		var arrow := "-->" if link.one_way else "<-->"
		var label := ("|%s|" % " · ".join(tags).replace("\"", "'")) if not tags.is_empty() else ""
		lines.append("  %s %s%s %s" % [ids[String(link.from)], arrow, label, ids[String(link.to)]])
	var text := "\n".join(lines)
	print(text)
	if not read.problems.is_empty():
		print("problemas: ", read.problems)
	var file := FileAccess.open("res://debug/tmp/%s.mmd" % name, FileAccess.WRITE)
	file.store_string(text + "\n")
	quit()


func _needs(clauses: Array) -> String:
	return " + ".join(clauses.map(func(clause: Array) -> String: return "|".join(clause).replace("|", " o ")))
