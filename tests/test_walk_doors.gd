extends "res://tests/test_case.gd"
## Cada puerta y reja de las mazmorras, abierta, deja pasar la cápsula del player en los dos sentidos y tiene suelo
## en el umbral: los demás tests teletransportan al player entre salas y no verían un paso tapado por un muro del kit.

const LEVELS := ["res://levels/chullpa.tscn", "res://levels/quenoa.tscn", "res://levels/templo.tscn"]
const REACH := 2.4


func test_every_open_door_can_be_walked_through() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for path: String in LEVELS:
		tree.root.get_node(^"GameState").reset()
		tree.change_scene_to_file(path)
		await tree.scene_changed
		await tree.create_timer(0.3).timeout
		var level := tree.current_scene as Node3D
		var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
		var body := player.get_node(^"CollisionShape3D") as CollisionShape3D
		var passages: Dictionary[Node3D, Vector3] = {}
		for door: Door in level.find_children("*", "Door", true, false):
			passages[door] = door.global_position
			door.reveal_on_open = false
			door.open(false)
		for gate: Gate in level.find_children("*", "Gate", true, false):
			passages[gate] = gate.global_position
			gate.reveal_on_open = false
			gate.open(false)
		await tree.create_timer(0.5).timeout
		var space := level.get_world_3d().direct_space_state
		for passage in passages:
			var across := passage.global_basis.z
			across.y = 0.0
			across = across.normalized()
			var ground: Variant = _ground(space, passages[passage] + Vector3.UP, player)
			assert_true(ground != null, "%s › %s: hay suelo en el umbral" % [path.get_file(), passage.name])
			if ground == null:
				ground = passages[passage]
			for side in [1.0, -1.0]:
				var way: Vector3 = across * side
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = body.shape
				query.exclude = [player.get_rid()]
				var past := 0.0
				while past < REACH:
					query.transform = Transform3D(Basis(), ground + Vector3.UP * (body.position.y + 0.1) + way * past)
					if space.intersect_shape(query, 1):
						break
					past += 0.2
				assert_true(past > 0.6, "%s › %s: la cápsula pasa hacia %s (libre %.1f m)" % [path.get_file(), passage.name, way.round(), past])


func _ground(space: PhysicsDirectSpaceState3D, from: Vector3, player: PlayerCharacter) -> Variant:
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.0)
	ray.exclude = [player.get_rid()]
	var hit := space.intersect_ray(ray)
	return hit.position if hit else null
