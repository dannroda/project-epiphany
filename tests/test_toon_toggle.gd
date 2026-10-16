extends "res://tests/test_case.gd"

const TOON := preload("res://src/shaders/toon/epiphany_toon.tres")
const PALETTE := preload("res://data/kits/materials/epiphany.tres")
const TOGGLE := preload("res://src/shaders/toon/toon_toggle.gd")


func _press() -> void:
	var event := InputEventAction.new()
	event.action = &"debug_toon"
	event.pressed = true
	Input.parse_input_event(event)
	await (Engine.get_main_loop() as SceneTree).process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await (Engine.get_main_loop() as SceneTree).process_frame


func test_toggle_swaps_palette_material_and_restores_it() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var toggle: Node = TOGGLE.new()
	tree.root.add_child(toggle)
	var mesh := BoxMesh.new()
	mesh.material = PALETTE
	var before := MeshInstance3D.new()
	before.mesh = mesh
	tree.root.add_child(before)
	await _press()
	assert_eq(before.get_active_material(0), TOON, "lo que ya estaba cargado")
	var after := MeshInstance3D.new()
	after.mesh = mesh
	tree.root.add_child(after)
	await tree.process_frame
	assert_eq(after.get_active_material(0), TOON, "lo que se carga después")
	await _press()
	assert_eq(before.get_active_material(0), PALETTE)
	assert_eq(after.get_active_material(0), PALETTE)
	before.queue_free()
	after.queue_free()
	toggle.queue_free()


func test_bound_to_key_4() -> void:
	var keys := InputMap.action_get_events(&"debug_toon").filter(func(e: InputEvent) -> bool: return e is InputEventKey)
	assert_true(keys.any(func(e: InputEventKey) -> bool: return e.physical_keycode == KEY_4))
