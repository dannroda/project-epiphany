extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"
const BOMB := preload("res://src/items/bomb/bomb.tscn")
const SLOT := 9


func _load(tree: SceneTree) -> void:
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame


func test_only_bombs_break_it_and_it_stays_broken() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var saves: Node = tree.root.get_node(^"SaveManager")
	state.reset()
	var before_break := ConfigFile.new()
	state.write_to(before_break)
	await _load(tree)
	var wall: CrackedWall = tree.current_scene.get_node(^"CrackedWall")
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var slash := Items.get_item(&"sword_basic").make_damage(player)
	slash.team = EntityConfig.Team.PLAYER
	wall.hurtbox.receive(slash)
	assert_eq(wall.is_broken, false, "la espada no lo rompe")

	var bomb: Bomb = BOMB.instantiate()
	tree.current_scene.add_child(bomb)
	bomb.global_position = wall.global_position + Vector3(0, 0.3, 1.4)
	await tree.create_timer(2.4).timeout
	assert_eq(wall.is_broken, true, "una bomba sí")
	assert_eq(wall.shape.disabled, true, "ya no bloquea el paso")
	assert_eq(state.get_flag(&"ow_test_cracked_wall"), true)

	assert_eq(saves.save_game(SLOT), OK)
	state.reset()
	await _load(tree)
	assert_eq(await saves.load_game(SLOT), OK)
	await tree.process_frame
	wall = tree.current_scene.get_node(^"CrackedWall")
	assert_eq(wall.is_broken, true, "sigue roto después de guardar y cargar")

	state.read_from(before_break)
	await tree.process_frame
	assert_eq(wall.is_broken, false, "una partida anterior lo vuelve a armar en la escena")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(SLOT)))
	state.reset()


func test_warns_about_bad_flag() -> void:
	var wall: CrackedWall = preload("res://src/world/cracked_wall.tscn").instantiate()
	wall.flag = &"ow_test_craked_wall"
	assert_eq(wall._get_configuration_warnings().size(), 1, "flag mal escrito")
	wall.flag = &""
	assert_eq(wall._get_configuration_warnings().size(), 1, "sin flag")
	wall.free()


func test_covers_hide_what_it_hides_until_it_breaks() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	await _load(tree)
	var wall: CrackedWall = tree.current_scene.get_node(^"CrackedWall")
	var roof := Node3D.new()
	tree.current_scene.add_child(roof)
	wall.covers = [wall.get_path_to(roof)]
	wall._show(false)
	assert_eq(roof.visible, true, "tapa el nicho")
	wall.smash()
	assert_eq(roof.visible, false, "al romperse se va")
	roof.free()
	state.reset()


## 11.181: en las mazmorras una pared agrietada abre una sala entera, nunca un nicho; en la Chullpa no hay ninguna.
func test_dungeon_cracked_walls_open_whole_rooms() -> void:
	for level_name in ["chullpa", "quenoa", "totora", "cumbre", "templo"]:
		var level := (load("res://levels/%s.tscn" % level_name) as PackedScene).instantiate()
		var walls := level.find_children("*", "CrackedWall", true, false).filter(func(wall: Node) -> bool: return not wall.scene_file_path.ends_with("cracked_floor.tscn"))
		if level_name == "chullpa":
			assert_eq(walls.size(), 0, "la Chullpa no tiene paredes agrietadas")
		var rooms := level.find_children("*", "Room", true, false)
		for wall: CrackedWall in walls:
			var sides: Array = []
			for side: float in [-3.0, 3.0]:
				var at: Vector3 = wall.position + wall.basis * Vector3.FORWARD * side
				var found := rooms.filter(func(room: Room) -> bool: return room.get_parent() == wall.get_parent() and _room_rect(room).has_point(Vector2(at.x, at.z)))
				sides.append(found[0] if not found.is_empty() else null)
			assert_true(sides[0] != null and sides[1] != null and sides[0] != sides[1], "%s/%s separa dos salas" % [level_name, wall.name])
		level.free()


func _room_rect(room: Room) -> Rect2:
	var box := (room.get_node(^"CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	return Rect2(room.position.x - box.size.x / 2.0, room.position.z - box.size.z / 2.0, box.size.x, box.size.z)
