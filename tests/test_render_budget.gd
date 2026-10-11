extends "res://tests/test_case.gd"
## Presupuesto de dibujo con la cámara cenital (10.25, 10.26).

const LEVELS := ["res://levels/overworld.tscn", "res://levels/temple.tscn"]


func test_the_sun_shadows_only_what_the_camera_sees() -> void:
	for path in LEVELS:
		var scene: Node = (load(path) as PackedScene).instantiate()
		var sun := scene.get_node(^"Sun") as DirectionalLight3D
		assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "%s: dos cascadas" % path.get_file())
		assert_true(sun.directional_shadow_max_distance <= 40.0, "%s: hasta donde llega la cámara" % path.get_file())
		scene.free()
