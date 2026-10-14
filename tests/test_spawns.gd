extends "res://tests/test_case.gd"
## 11.83: lo de runtime cuelga de un solo nodo (Spawns.root) y una oleada acepta cualquier cosa con `defeated`.

const LEVEL := "res://levels/test.tscn"
const TURRET := preload("res://src/entities/turret/turret.tscn")
const ORB := preload("res://src/entities/projectile.tscn")


func _load() -> SceneTree:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.physics_frame
	return tree


func test_runtime_objects_hang_from_the_spawn_root() -> void:
	var tree := await _load()
	var level := tree.current_scene
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var info := DamageInfo.make(1, 0.0, player)
	var orb := Projectile.fire(ORB, player, player.global_position + Vector3(0, 1, 2), Vector3.BACK, info)
	assert_eq(orb.get_parent(), level, "sin raíz propia: la escena actual")
	orb.queue_free()
	var root := Node3D.new()
	root.add_to_group(Spawns.GROUP)
	level.add_child(root)
	orb = Projectile.fire(ORB, player, player.global_position + Vector3(0, 1, 2), Vector3.BACK, info)
	assert_eq(orb.get_parent(), root, "el proyectil cuelga de la raíz de spawn")
	var table := DropTable.new()
	var entry := DropEntry.new()
	entry.heal = 4
	table.entries.assign([entry])
	var pickup := table.drop_at(player.global_position + Vector3(3, 0, 0), player)
	assert_eq(pickup.get_parent(), root, "el pickup también")
	root.queue_free()
	await tree.process_frame


func test_a_turret_in_a_wave_counts_as_beaten() -> void:
	var tree := await _load()
	var level := tree.current_scene
	var spawner := WaveSpawner.new()
	var wave := Node3D.new()
	var spawn := WaveSpawn.new()
	spawn.enemy = TURRET
	spawn.position = Vector3(6, 0, 6)
	wave.add_child(spawn)
	spawner.add_child(wave)
	level.add_child(spawner)
	spawner.start()
	await tree.process_frame
	var turrets := level.find_children("*", "Turret", true, false).filter(func(each: Node) -> bool:
		return (each as Node3D).global_position.distance_to(spawn.global_position) < 0.1)
	assert_eq(turrets.size(), 1, "aparece la torreta")
	var turret := turrets[0] as Turret
	turret.health.damage(turret.health.current, true)
	await tree.process_frame
	assert_true(spawner.active, "vencida la torreta, la oleada se gana")
	spawner.queue_free()
	turret.queue_free()
	await tree.process_frame
