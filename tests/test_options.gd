extends "res://tests/test_case.gd"

const TEST_PATH := "user://test_settings.cfg"


func _settings() -> Node:
	var settings: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"Settings")
	settings.path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	settings.load_settings()
	return settings


func _restore(settings: Node) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	settings.path = "user://test_settings.cfg"
	settings.load_settings()


func test_every_option_persists_and_applies() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var settings := _settings()
	var changes := {&"lock_toggle": true, &"mouse_aim": false, &"stick_sensitivity": 80, &"flick": false, &"vibration": false, &"music": 30, &"sfx": 40, &"ambience": 0, &"shake": false, &"ui_scale": 125}
	for key in changes:
		settings.set_value(key, changes[key])
	settings.values = settings.DEFAULTS.duplicate()
	settings.load_settings()
	for key in changes:
		assert_eq(settings.get_value(key), changes[key], "%s se mantiene al reiniciar" % key)
	assert_true(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")) - linear_to_db(0.3)) < 0.01, "volumen de música")
	assert_eq(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Ambience")), true, "ambiente en 0: muteado")
	assert_eq(tree.root.get_node(^"Feel").settings.shake_enabled, false, "sin temblor de cámara")
	assert_true(is_equal_approx(tree.root.content_scale_factor, 1.25), "escala de la interfaz")

	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/test.tscn")
	await tree.scene_changed
	await tree.process_frame
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	assert_eq(player.targeting.lock_mode, Targeting.LockMode.TOGGLE, "fijar objetivo: alternar")
	assert_eq(player.targeting.flick_enabled, false, "sin flick")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(5, 5)
	player.aim._input(motion)
	assert_eq(player.aim.mouse_aims(), false, "sin apuntar con el mouse")
	assert_true(settings.stick_factor() > 1.2, "sensibilidad alta")
	_restore(settings)
	assert_eq(settings.get_value(&"lock_toggle"), false)


func test_options_from_title_and_pause() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var settings := _settings()
	tree.change_scene_to_file("res://src/ui/title/title_screen.tscn")
	await tree.scene_changed
	await tree.process_frame
	var title := tree.current_scene
	assert_eq(title.get_node(^"%Options").disabled, false, "Opciones habilitado en el título")
	title.get_node(^"%Options").grab_focus()
	title.get_node(^"%Options").pressed.emit()
	await tree.process_frame
	await tree.process_frame
	var stack: Node = tree.root.get_node(^"MenuStack")
	var screen := stack.top() as OptionsScreen
	assert_true(screen != null, "abre la pantalla de opciones")
	assert_eq(title.can_process(), false, "el título de abajo no recibe input")
	assert_true(tree.root.gui_get_focus_owner() != null and screen.is_ancestor_of(tree.root.gui_get_focus_owner()), "con foco en una opción")
	(screen.find_child("vibration", true, false) as CheckBox).button_pressed = false
	assert_eq(settings.get_value(&"vibration"), false, "cambiar en la pantalla guarda")
	var back := InputEventAction.new()
	back.action = &"ui_cancel"
	back.pressed = true
	tree.root.push_input(back)
	await tree.process_frame
	assert_eq(stack.is_open(), false, "atrás cierra las opciones")
	assert_true(title.can_process() and title.visible, "y el título vuelve a recibir input")
	assert_true(tree.root.gui_get_focus_owner() == title.get_node(^"%Options"), "con el foco donde estaba")

	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/test.tscn")
	await tree.scene_changed
	var menu: Control = load("res://src/ui/menus/pause_menu.tscn").instantiate()
	stack.push(menu)
	await tree.process_frame
	menu.show_page(3)
	await tree.process_frame
	var page: Control = menu.pages.get_node(^"Sistema")
	assert_true(page.visible, "la pausa tiene la pestaña Sistema")
	assert_true(page.find_child("SaveAndQuit", true, false) is Button, "con Guardar y salir al título")
	while stack.is_open():
		stack.pop()
	_restore(settings)
