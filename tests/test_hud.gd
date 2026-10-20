extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func _quarters(tree: SceneTree) -> Array:
	var hud: Node = tree.current_scene.get_node(^"HUD")
	return hud.hearts.get_children().map(func(h: HeartIcon) -> int: return h.quarters)


func test_hearts_follow_health() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var game_state: Node = tree.root.get_node(^"GameState")
	game_state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.process_frame
	await tree.process_frame
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	assert_eq(_quarters(tree), [4, 4, 4], "3 corazones llenos")
	player.health.invulnerability_time = 0.0
	player.health.damage(1)
	assert_eq(_quarters(tree), [4, 4, 3], "un cuarto menos")
	player.health.damage(4)
	assert_eq(_quarters(tree), [4, 3, 0], "un corazón menos")
	player.health.heal(2)
	assert_eq(_quarters(tree), [4, 4, 1])
	game_state.max_health = 20
	game_state.set_health_of(0, 20)
	game_state.loaded.emit()
	assert_eq(_quarters(tree), [4, 4, 4, 4, 4], "más vida máxima, más corazones")
	game_state.reset()


func test_item_slots_follow_buttons_and_ammo() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var device: Node = tree.root.get_node(^"InputDevice")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.process_frame
	var hud: Node = tree.current_scene.get_node(^"HUD")
	var x: Control = hud.item_slots.get_child(0).get_node(^"Body")
	var y: Control = hud.item_slots.get_child(1).get_node(^"Body")
	assert_eq(x.get_node(^"Icon").texture, null, "vacío sin ítem asignado")
	assert_eq(x.visible, false, "el slot vacío no se muestra")
	assert_eq(y.visible, false)
	assert_eq(x.get_node(^"Ammo").visible, false)

	state.give(Items.get_item(&"bow"))
	state.give(Items.get_item(&"bomb_bag"))
	state.inventory.remove(&"arrow", state.inventory.count(&"arrow"))
	state.inventory.remove(&"bomb", state.inventory.count(&"bomb"))
	state.give(Items.get_item(&"arrow"), 12)
	state.assign_button(0, &"bow")
	assert_eq(x.get_node(^"Icon").texture, Items.get_item(&"bow").icon)
	assert_eq(x.visible, true, "con ítem se muestra")
	assert_eq(x.get_node(^"Ammo").text, "12")
	state.inventory.remove(&"arrow")
	assert_eq(x.get_node(^"Ammo").text, "11", "la munición baja")

	state.assign_button(0, &"bomb_bag")
	assert_eq(x.get_node(^"Icon").texture, Items.get_item(&"bomb_bag").icon, "reasignar cambia el slot")
	assert_eq(x.get_node(^"Ammo").text, "0")
	assert_eq(y.get_node(^"Icon").texture, Items.get_item(&"bow").icon, "intercambio con Y")

	device._switch_to(1)
	assert_eq(x.get_node(^"Badge").texture, InputPrompts.icon(&"item_1", true), "ícono de gamepad")
	device._switch_to(0)
	assert_eq(x.get_node(^"Badge").texture, InputPrompts.icon(&"item_1", false), "ícono de teclado")
	state.reset()


func test_a_heart_shows_whole_quarters_counterclockwise() -> void:
	var heart := HeartIcon.create(3)
	(Engine.get_main_loop() as SceneTree).root.add_child(heart)
	var shown: Array = heart.quarter_nodes.map(func(q: Control) -> bool: return q.visible)
	assert_eq(shown, [true, true, true, false], "tres cuartos: falta el de arriba a la derecha")
	assert_eq(heart.quarter_nodes[2].position, HeartIcon.SIZE / 2.0, "el tercero es el de abajo a la derecha")
	heart.free()


## 16.41: re-mostrar el nombre de zona o esconder la barra del jefe a mitad del fundido sigue desde el alfa que tiene.
func test_fades_restart_from_the_current_alpha() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var hud := (load("res://src/ui/hud/hud.tscn") as PackedScene).instantiate() as Hud
	tree.root.add_child(hud)
	hud.show_area_name("A")
	await tree.create_timer(1.0).timeout
	hud.show_area_name("B")
	await tree.create_timer(0.1).timeout
	assert_true(hud.area_label.get_parent().modulate.a > 0.95, "el nombre visible no vuelve a 0 (%.2f)" % hud.area_label.get_parent().modulate.a)
	var fight := ArenaFight.new()
	var bar := BossBar.new("X", fight.bar_changed, func() -> float: return 1.0)
	hud.show_boss(bar)
	await tree.create_timer(0.2).timeout
	var half := hud.boss_bar.modulate.a
	hud.hide_boss()
	await tree.create_timer(0.1).timeout
	assert_true(half < 0.9 and hud.boss_bar.modulate.a <= half + 0.05, "esconder en la entrada no salta a 1 (%.2f → %.2f)" % [half, hud.boss_bar.modulate.a])
	hud.free()
	fight.free()


## 16.34: el mundo le avisa al HUD por las señales de Hud.events, y uno liberado deja de escuchar.
func test_events_reach_the_hud() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var before := Hud.events.area_announced.get_connections().size()
	var hud := (load("res://src/ui/hud/hud.tscn") as PackedScene).instantiate() as Hud
	tree.root.add_child(hud)
	Hud.events.area_announced.emit("Chullpa")
	assert_eq(hud.area_label.text, "Chullpa")
	var fight := ArenaFight.new()
	Hud.events.boss_shown.emit(BossBar.new("X", fight.bar_changed, func() -> float: return 0.5))
	assert_true(is_equal_approx(hud.boss_health.value, 0.5), "la barra toma la fracción (%.2f)" % hud.boss_health.value)
	Hud.events.boss_hidden.emit()
	assert_true(hud._boss == null, "suelta la barra")
	hud.free()
	fight.free()
	assert_eq(Hud.events.area_announced.get_connections().size(), before, "el HUD liberado se desconecta")
