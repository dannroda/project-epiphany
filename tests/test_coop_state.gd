extends "res://tests/test_case.gd"
## Co-op (13.11): lo de un player no se cuela en el otro.

const PAD_1 := 0
const PAD_2 := 1


func _rooms() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var players: Node = tree.root.get_node(^"Players")
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/test_rooms.tscn")
	await tree.scene_changed
	for i in 4:
		await tree.physics_frame
	tree.current_scene.get_node(^"Skeleton").free()
	players.lead_pad = PAD_1
	var second: PlayerCharacter = players.join(PAD_2)
	for i in 3:
		await tree.physics_frame
	return [tree, tree.current_scene, players.lead(), second]


func _done() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var players: Node = tree.root.get_node(^"Players")
	for slot in players.guests.keys():
		players.leave(slot)
	players.lead_pad = -1
	MenuStack.clear()
	tree.paused = false
	await tree.process_frame
	tree.root.get_node(^"GameState").reset()


func test_each_player_has_its_own_animation_tree() -> void:
	var setup: Array = await _rooms()
	var first: PlayerCharacter = setup[2]
	var second: PlayerCharacter = setup[3]
	assert_true(first.anim_tree.tree_root != second.anim_tree.tree_root, "cada uno con su árbol")
	var item_anim := func(player: PlayerCharacter) -> AnimationNodeAnimation:
		return (player.anim_tree.tree_root as AnimationNodeBlendTree).get_node(&"ItemAnim")
	var before: StringName = item_anim.call(second).animation
	(item_anim.call(first) as AnimationNodeAnimation).animation = &"General/Throw"
	assert_eq(item_anim.call(second).animation, before, "la animación de ítem de uno no cambia la del otro")
	await _done()


func test_bomb_cap_is_per_player() -> void:
	var setup: Array = await _rooms()
	var level: Node = setup[1]
	var first: PlayerCharacter = setup[2]
	var second: PlayerCharacter = setup[3]
	var state: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"GameState")
	state.give(Items.get_item(&"bomb_bag"))
	var bag := Items.get_item(&"bomb_bag")
	var behavior: ItemBehavior = bag.behavior
	var context := func(user: PlayerCharacter) -> ItemUseContext:
		var ctx := ItemUseContext.new()
		ctx.user = user
		ctx.inventory = state.inventory
		ctx.direction = Vector3.FORWARD
		return ctx
	for i in behavior.get(&"max_active"):
		var ctx: ItemUseContext = context.call(first)
		var bomb: Node3D = behavior.spawn(ctx)
		level.add_child(bomb)
		bomb.global_position = first.global_position + Vector3(i, 2, 0)
	assert_true(not behavior.can_use(context.call(first), bag), "el que llegó al tope no pone otra")
	assert_true(behavior.can_use(context.call(second), bag), "el otro sí: las bombas del primero no cuentan")
	for bomb in level.get_tree().get_nodes_in_group(&"bombs"):
		bomb.free()
	await _done()


func test_the_tremor_keeps_going_while_any_player_is_inside() -> void:
	var setup: Array = await _rooms()
	var first: PlayerCharacter = setup[2]
	var second: PlayerCharacter = setup[3]
	var zone := TremorZone.new()
	setup[1].add_child(zone)
	zone.body_entered.emit(first)
	zone.body_entered.emit(second)
	zone.body_exited.emit(first)
	var trembles := [0]
	zone.trembled.connect(func() -> void: trembles[0] += 1)
	zone.interval = 0.1
	await (setup[0] as SceneTree).create_timer(2.0).timeout
	assert_true(trembles[0] > 0, "con el segundo adentro sigue temblando")
	zone.body_exited.emit(second)
	trembles[0] = 0
	await (setup[0] as SceneTree).create_timer(0.5).timeout
	assert_eq(trembles[0], 0, "sin nadie adentro, para")
	zone.free()
	await _done()


func test_mouse_aim_does_not_depend_on_the_last_device_of_anyone() -> void:
	var setup: Array = await _rooms()
	var first: PlayerCharacter = setup[2]
	var settings: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"Settings")
	var device: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"InputDevice")
	var mouse_aim: Variant = settings.get_value(&"mouse_aim")
	settings.set_value(&"mouse_aim", true)
	device.current = InputDevice.Device.GAMEPAD
	first.aim._mouse_moved = true
	assert_true(first.aim.mouse_aims(), "otro player con pad no le apaga el apuntado con ratón")
	device.current = InputDevice.Device.KEYBOARD_MOUSE
	settings.set_value(&"mouse_aim", mouse_aim)
	await _done()


func test_the_zone_banner_follows_the_lead_player() -> void:
	var setup: Array = await _rooms()
	var first: PlayerCharacter = setup[2]
	var second: PlayerCharacter = setup[3]
	var zone := AreaZone.new()
	zone.display_name = "PLACE_MEADOW"
	setup[1].add_child(zone)
	var before := AreaZone._current
	zone.body_entered.emit(second)
	assert_eq(AreaZone._current, before, "si cruza el segundo, el banner no cambia")
	zone.body_entered.emit(first)
	assert_eq(AreaZone._current, zone, "si cruza el que manda, sí")
	zone.free()
	AreaZone._current = null
	await _done()


## La zona actual se olvida al irse de la escena: la siguiente no compara contra una zona liberada.
func test_the_current_zone_is_forgotten_with_its_scene() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var zone := AreaZone.new()
	tree.root.add_child(zone)
	AreaZone._current = zone
	zone.free()
	assert_true(AreaZone._current == null, "sin zona colgada")


func test_joined_comes_once_the_player_is_ready() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var players: Node = tree.root.get_node(^"Players")
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/test_rooms.tscn")
	await tree.scene_changed
	await tree.physics_frame
	var seen := []
	var on_joined := func(player: PlayerCharacter) -> void:
		seen.append(player.is_node_ready() and player.health != null and player.health.max_health > 0)
	players.joined.connect(on_joined)
	players.lead_pad = PAD_1
	players.join(PAD_2)
	await tree.physics_frame
	players.joined.disconnect(on_joined)
	assert_eq(seen, [true], "joined sale una vez, con el player listo")
	await _done()
