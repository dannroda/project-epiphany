extends "res://tests/test_case.gd"

const PICKUP := preload("res://src/world/props/pickup.tscn")


func _shown(item: ItemData) -> Node3D:
	var pickup: Pickup = PICKUP.instantiate()
	pickup.item = item
	pickup.heal = 0 if item else 4
	(Engine.get_main_loop() as SceneTree).root.add_child(pickup)
	var shown: Node3D = pickup.get_node(^"Model") if pickup.get_node(^"Model").visible else pickup.get_node(^"Sprite")
	pickup.queue_free()
	return shown


func test_hearts_arrows_and_bombs_lie_as_models() -> void:
	for item in [null, Items.get_item(&"arrow"), Items.get_item(&"bomb"), Items.get_item(&"heart_piece")]:
		var shown := _shown(item)
		assert_true(shown is MeshInstance3D and (shown as MeshInstance3D).mesh != null, "%s con malla" % (item.id if item else &"corazón"))
	assert_true(_shown(Items.get_item(&"compass")) is Sprite3D, "sin malla, el ícono")


func test_the_orb_is_an_energy_sphere() -> void:
	var orb: Node = preload("res://src/entities/projectile.tscn").instantiate()
	var material := (orb.get_node(^"Mesh") as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
	assert_eq(material.shader.resource_path, "res://src/world/vfx/esfera_energia.gdshader")
	orb.free()
