extends "res://tests/test_case.gd"
## Al caer al agua o a un pozo se vuelve a la entrada de la sala (GameState.room_entry): tiene que quedar sobre piso firme,
## o el player cae de nuevo en bucle (11.149).

const LEVELS := ["res://levels/chullpa.tscn", "res://levels/quenoa.tscn", "res://levels/templo.tscn", "res://levels/totora.tscn", "res://levels/cumbre.tscn"]
const ACTIONS := {Vector3.RIGHT: &"move_right", Vector3.LEFT: &"move_left", Vector3.FORWARD: &"move_forward", Vector3.BACK: &"move_backward"}


func _walk(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0
	Input.parse_input_event(event)


func _ground(space: PhysicsDirectSpaceState3D, from: Vector3, player: PlayerCharacter) -> Variant:
	var ray := PhysicsRayQueryParameters3D.create(from + Vector3.UP, from + Vector3.DOWN * 2.0, 1, [player.get_rid()])
	var hit := space.intersect_ray(ray)
	return hit.position if hit else null


func _in_boss_room(tree: SceneTree, point: Vector3) -> bool:
	for room: Room in tree.get_nodes_in_group(Room.GROUP):
		if room.boss_room and room.contains(point):
			return true
	return false


func test_entering_any_room_leaves_the_return_point_on_solid_floor() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	for path: String in LEVELS:
		state.reset()
		tree.change_scene_to_file(path)
		await tree.scene_changed
		await tree.create_timer(0.3).timeout
		var level := tree.current_scene as Node3D
		for enemy in tree.get_nodes_in_group(&"enemies"):
			enemy.free()
		var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
		player.health.invulnerability_time = 0.0
		player.health.max_health = 9999
		var space := level.get_world_3d().direct_space_state
		var doors: Array[Node] = level.find_children("*", "Door", true, false)
		for door: Door in doors:
			door.reveal_on_open = false
			door.open(false)
		await tree.create_timer(0.5).timeout
		for door: Door in doors:
			var across := door.global_basis.z
			across.y = 0.0
			across = across.normalized().round()
			across = Vector3(across.x + 0.0, 0.0, across.z + 0.0)
			if not ACTIONS.has(across):
				continue
			for side in [1.0, -1.0]:
				var way: Vector3 = Vector3(across.x * side + 0.0, 0.0, across.z * side + 0.0)
				var start: Variant = _ground(space, door.global_position - way * 2.4, player)
				if start == null or _in_boss_room(tree, door.global_position - way * 2.4) or _in_boss_room(tree, door.global_position + way * 2.4):
					continue
				if not is_instance_valid(player) or player.is_dead:
					return
				player.health.heal(9999)
				player.global_position = start
				player.velocity = Vector3.ZERO
				for i in 20:
					await tree.physics_frame
				state.room_entry = null
				var hp := player.health.current
				_walk(ACTIONS[way], true)
				var until := Time.get_ticks_msec() + 2500
				while Time.get_ticks_msec() < until and state.room_entry == null:
					await tree.physics_frame
				_walk(ACTIONS[way], false)
				if state.room_entry == null:
					continue
				var camera := tree.get_first_node_in_group(&"room_camera") as TopDownCamera
				while camera.transitioning:
					await tree.physics_frame
				await tree.create_timer(0.3).timeout
				var entry: Vector3 = state.room_entry
				var floor_hit: Variant = _ground(space, entry, player)
				var label := "%s › %s hacia %s" % [path.get_file(), door.get_path().get_name(door.get_path().get_name_count() - 1), way]
				assert_true(floor_hit != null and absf(floor_hit.y - entry.y) < 0.3, "%s: la vuelta (%s) queda sobre piso" % [label, entry.snappedf(0.1)])
				assert_eq(player.health.current, hp, "%s: la caminata del cruce no lo tira" % label)
				if not is_instance_valid(player) or player.is_dead:
					assert_true(false, "%s: murió entrando" % label)
					return
				player.global_position = entry
				player.velocity = Vector3.ZERO
				hp = player.health.current
				await tree.create_timer(0.8).timeout
				assert_eq(player.health.current, hp, "%s: desde la vuelta no vuelve a caer" % label)
	state.reset()
