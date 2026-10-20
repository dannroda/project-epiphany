extends "res://tests/test_case.gd"
## Los campamentos de los Devotos del Ojo (11.115): fogón y estandarte en el Cardonal y el Bañado, sobre piso que se
## camina y lejos de los portales de viaje, así nadie llega por el portal al medio de la pelea.

const LEVEL := "res://levels/overworld.tscn"
const CAMPS := {"Cardonal": &"Zone_cardonal", "Banado": &"Zone_banado"}
const PORTAL_CLEARANCE := 15.0
const DEVOTO := "res://src/entities/devoto/devoto.tscn"


func test_each_camp_has_a_fire_and_a_banner_on_walkable_ground() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 10:
		await tree.physics_frame
	var level := tree.current_scene
	var space := (level as Node3D).get_world_3d().direct_space_state
	for camp: String in CAMPS:
		var zone := level.get_node(NodePath(String(CAMPS[camp]))) as AreaZone
		for prop in ["Fogon", "Estandarte"]:
			var node := level.get_node_or_null(prop + camp) as Node3D
			assert_true(node != null, "%s tiene %s" % [camp, prop])
			if node == null:
				continue
			var at := node.global_position
			assert_true(zone.bounds().has_point(Vector2(at.x, at.z)), "%s%s está en %s" % [prop, camp, zone.name])
			var ray := PhysicsRayQueryParameters3D.create(at + Vector3(1.0, 3.0, 1.0), at + Vector3(1.0, -3.0, 1.0), 1)
			var hit := space.intersect_ray(ray)
			assert_true(not hit.is_empty() and absf(hit.position.y - at.y) < 0.3, "al lado de %s%s se pisa a su altura" % [prop, camp])
			for portal in tree.get_nodes_in_group(TravelPortal.GROUP):
				var gap := Vector2(at.x - portal.global_position.x, at.z - portal.global_position.z).length()
				assert_true(gap > PORTAL_CLEARANCE, "%s%s lejos de %s (%.1f m)" % [prop, camp, portal.name, gap])
		var fire := level.get_node(NodePath("Fogon" + camp)) as Node3D
		var guards := 0
		for node in level.get_children():
			if node.name.begins_with("Devoto" + camp) and node.scene_file_path == DEVOTO:
				guards += 1
				assert_true((node as Node3D).global_position.distance_to(fire.global_position) < 5.0, "%s cuida el fogón" % node.name)
		assert_true(guards >= 2, "%s tiene Devotos (%d)" % [camp, guards])
