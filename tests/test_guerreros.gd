extends "res://tests/test_case.gd"
## Los enemigos comunes de cada mazmorra (12.39): cada variante lleva el modelo y las armas de su mazmorra.

const DUNGEONS := ["chullpa", "quenoa", "totora", "cumbre", "templo"]
const KINDS := ["skeleton", "shield_skeleton", "archer_skeleton", "armored_skeleton"]


func test_every_variant_wears_its_dungeon() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/test.tscn")
	await tree.scene_changed
	for kind: String in KINDS:
		for dungeon: String in DUNGEONS:
			var enemy := (load("res://src/entities/guerreros/%s_%s.tscn" % [kind, dungeon]) as PackedScene).instantiate() as Node3D
			tree.current_scene.add_child(enemy)
			enemy.global_position = Vector3(0, 0, -30)
			await tree.process_frame
			var paths := enemy.find_children("*", "MeshInstance3D", true, false).filter(func(m: MeshInstance3D) -> bool: return m.is_visible_in_tree() and m.mesh != null).map(func(m: MeshInstance3D) -> String: return m.mesh.resource_path)
			var label := "%s_%s" % [kind, dungeon]
			assert_true(paths.any(func(p: String) -> bool: return p.contains("guerrero_" + dungeon)), label + " tiene su cuerpo")
			assert_true(paths.any(func(p: String) -> bool: return p.contains("armas_guerreros") and p.ends_with("_%s.res" % dungeon)), label + " tiene su arma")
			assert_true(not paths.any(func(p: String) -> bool: return p.contains("meshes/chullpa/") or p.ends_with("espada.res") or p.ends_with("equipo/armadura.res")), label + " no lleva la espada ni el cuerpo de siempre")
			if kind == "armored_skeleton":
				assert_true(paths.has("res://assets/epiphany/meshes/armas_guerreros/armadura_%s.res" % dungeon), label + " tiene su armadura")
			enemy.free()


func test_variants_share_their_kind_config() -> void:
	for kind: String in KINDS:
		var base := load("res://data/entities/%s.tres" % kind)
		for dungeon: String in DUNGEONS:
			var enemy := (load("res://src/entities/guerreros/%s_%s.tscn" % [kind, dungeon]) as PackedScene).instantiate() as Enemy
			assert_true(enemy.config == base, "%s_%s usa la config de %s" % [kind, dungeon, kind])
			assert_true(enemy.visuals != null, "%s_%s trae el cuerpo de su mazmorra" % [kind, dungeon])
			enemy.free()
	for file in DirAccess.get_files_at("res://data/entities"):
		for dungeon: String in DUNGEONS:
			assert_true(not file.ends_with("_%s.tres" % dungeon), "%s: sin configs por mazmorra" % file)
