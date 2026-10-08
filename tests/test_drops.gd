extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"
const SKELETON_DROPS: DropTable = preload("res://data/drops/skeleton.tres")


func _kinds(rolls: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var kinds := {}
	for i in rolls:
		var entry := SKELETON_DROPS.roll(rng)
		var kind: String = "nada" if entry.is_nothing() else ("corazón" if entry.heal > 0 else String(entry.item.id))
		kinds[kind] = kinds.get(kind, 0) + 1
	return kinds


func test_only_hearts_without_bag_or_bow() -> void:
	var state: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"GameState")
	state.reset()
	var kinds := _kinds(20, 7)
	assert_eq(kinds.keys().filter(func(k: String) -> bool: return k not in ["nada", "corazón"]), [], "20 esqueletos: solo corazones (o nada)")
	assert_true(kinds.get("corazón", 0) > 0, "algún corazón")
	state.give(Items.get_item(&"bomb_bag"))
	kinds = _kinds(200, 7)
	assert_true(kinds.get("bomb", 0) > 0, "con la bolsa también caen bombas")
	assert_eq(kinds.get("arrow", 0), 0, "sin arco no caen flechas")
	state.reset()


func test_pickup_heals_and_gives() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.physics_frame
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	player.health.damage(5)
	var heart := preload("res://src/world/pickup.tscn").instantiate() as Pickup
	heart.heal = 4
	tree.current_scene.add_child(heart)
	heart.global_position = player.global_position
	await tree.create_timer(0.5).timeout
	assert_eq(player.health.current, 11, "el corazón cura 4")
	assert_eq(is_instance_valid(heart), false, "desaparece al agarrarlo")
	state.give(Items.get_item(&"bomb_bag"))
	var bombs := preload("res://src/world/pickup.tscn").instantiate() as Pickup
	bombs.item = Items.get_item(&"bomb")
	bombs.amount = 3
	tree.current_scene.add_child(bombs)
	bombs.global_position = player.global_position + Vector3(1.5, 0, 0)
	await tree.create_timer(1.0).timeout
	assert_eq(state.inventory.count(&"bomb"), 3, "el imán lo acerca y da 3 bombas")
	state.reset()


func test_enemy_drops_on_death() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.physics_frame
	var enemy := tree.get_first_node_in_group(&"enemies") as Enemy
	var always := DropTable.new()
	var entry := DropEntry.new()
	entry.heal = 4
	always.entries.assign([entry])
	var original := enemy.config.drops
	enemy.config.drops = always
	var died_at := enemy.global_position
	enemy.on_death_finished()
	await tree.process_frame
	enemy.config.drops = original
	var pickups := tree.current_scene.get_children().filter(func(n: Node) -> bool: return n is Pickup)
	assert_eq(pickups.size(), 1, "suelta un recolectable")
	if pickups.size() == 1:
		assert_true(pickups[0].global_position.distance_to(died_at) < 0.1, "donde murió")
	state.reset()
