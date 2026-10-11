extends "res://tests/test_case.gd"

const PICKUP := preload("res://src/world/pickup.tscn")


func _shown(item: ItemData) -> Node3D:
	var pickup: Pickup = PICKUP.instantiate()
	pickup.item = item
	pickup.heal = 0 if item else 4
	(Engine.get_main_loop() as SceneTree).root.add_child(pickup)
	var shown: Node3D = pickup.get_node(^"Model") if pickup.get_node(^"Model").visible else pickup.get_node(^"Sprite")
	pickup.queue_free()
	return shown


func test_hearts_arrows_and_bombs_lie_as_models() -> void:
	for item in [null, Items.get_item(&"arrow"), Items.get_item(&"bomb")]:
		var shown := _shown(item)
		assert_true(shown is MeshInstance3D and (shown as MeshInstance3D).mesh != null, "%s con malla" % (item.id if item else &"corazón"))
	assert_true(_shown(Items.get_item(&"heart_piece")) is Sprite3D, "sin malla, el ícono")


func test_the_orb_uses_its_model() -> void:
	var orb: Node = preload("res://src/entities/projectile.tscn").instantiate()
	assert_eq((orb.get_node(^"Mesh") as MeshInstance3D).mesh.resource_path, "res://assets/epiphany/meshes/objetos/orbe.res")
	orb.free()
