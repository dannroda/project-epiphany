extends "res://tests/test_case.gd"


func _settings() -> Node:
	var settings: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"Settings")
	settings.path = settings_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	settings.load_settings()
	settings.set_value(&"language", "es")
	return settings


func _restore(settings: Node) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	settings.path = settings_path
	settings.load_settings()
	settings.set_value(&"language", "es")


func test_every_option_persists_and_applies() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var settings := _settings()
	var changes := {&"lock_toggle": true, &"mouse_aim": false, &"stick_sensitivity": 80, &"flick": false, &"vibration": false, &"music": 30, &"sfx": 40, &"ambience": 0, &"shake": false, &"ui_scale": 125, &"max_fps": 120, &"shadows": 1, &"ssao": false, &"render_scale": 70, &"language": "en"}
	for key in changes:
		settings.set_value(key, changes[key])
	settings.values = settings.DEFAULTS.duplicate()
	settings.load_settings()
	for key in changes:
		assert_eq(settings.get_value(key), changes[key], "%s se mantiene al reiniciar" % key)
	assert_true(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")) - linear_to_db(0.3)) < 0.01, "volumen de música")
	assert_eq(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Ambience")), true, "ambiente en 0: muteado")
	assert_eq(tree.root.get_node(^"Feel").shakes(), false, "sin temblor de cámara")
	assert_true(is_equal_approx(tree.root.content_scale_factor, 1.25), "escala de la interfaz")
	assert_true(is_equal_approx(tree.root.scaling_3d_scale, 0.7) and tree.root.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR, "resolución 3D al 70 % con FSR")
	assert_eq(TranslationServer.get_locale(), "en", "idioma")

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


## 15.4: la opción apaga el SSAO y la sombra del sol que trae el nivel, también al volver a cargarlo, y los devuelve.
func test_ssao_and_sun_shadow_follow_the_option() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var settings := _settings()
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/chullpa.tscn")
	await tree.scene_changed
	var env := (tree.current_scene.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment).environment
	var sun := tree.current_scene.find_children("*", "DirectionalLight3D", true, false)[0] as DirectionalLight3D
	assert_true(env.ssao_enabled and sun.shadow_enabled, "la mazmorra trae SSAO y sombra del sol")
	settings.set_value(&"ssao", false)
	settings.set_value(&"shadows", 0)
	assert_true(not env.ssao_enabled and not sun.shadow_enabled, "apagados con la opción")
	tree.change_scene_to_file("res://levels/chullpa.tscn")
	await tree.scene_changed
	env = (tree.current_scene.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment).environment
	sun = tree.current_scene.find_children("*", "DirectionalLight3D", true, false)[0] as DirectionalLight3D
	assert_true(not env.ssao_enabled and not sun.shadow_enabled, "siguen apagados al volver a entrar")
	settings.set_value(&"ssao", true)
	settings.set_value(&"shadows", 1)
	assert_true(env.ssao_enabled and sun.shadow_enabled, "vuelven al prenderlos")
	tree.change_scene_to_file("res://levels/test.tscn")
	await tree.scene_changed
	assert_true(not (tree.current_scene.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment).environment.ssao_enabled, "un nivel sin SSAO no lo prende")
	_restore(settings)


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
	for item in ["Save", "Load", "Options", "ToTitle"]:
		assert_true(page.find_child(item, true, false) is Button, "con %s" % item)
	(page.find_child("Options", true, false) as Button).pressed.emit()
	await tree.process_frame
	assert_true(stack.top() is OptionsScreen, "Opciones abre la pantalla de opciones")
	while stack.is_open():
		stack.pop()
	_restore(settings)


func test_a_slider_saves_when_released_not_on_every_step() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var settings := _settings()
	var panel: Control = load("res://src/ui/menus/options_panel.tscn").instantiate()
	tree.root.add_child(panel)
	var slider := panel.find_child("music", true, false) as Slider
	var stored := func() -> Variant:
		var cfg := ConfigFile.new()
		cfg.load(settings_path)
		return cfg.get_value("options", "music", null)
	var before: Variant = stored.call()
	for value in [20, 30, 40]:
		slider.value = value
	assert_eq(settings.get_value(&"music"), 40, "mientras se arrastra se aplica")
	assert_true(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")) - linear_to_db(0.4)) < 0.01, "y suena con ese volumen")
	assert_eq(stored.call(), before, "pero no escribe a disco en cada paso")
	slider.drag_ended.emit(true)
	assert_eq(stored.call(), 40, "al soltar, se guarda")
	slider.value = 50
	panel.free()
	assert_eq(stored.call(), 50, "al cerrar la pantalla también")
	_restore(settings)


func test_settings_are_read_typed_and_written_whole() -> void:
	var settings := _settings()
	var cfg := ConfigFile.new()
	cfg.set_value("options", "music", "fuerte")
	cfg.set_value("options", "sfx", 30)
	cfg.save(settings_path)
	settings.load_settings()
	assert_eq(settings.get_value(&"music"), settings.DEFAULTS[&"music"], "un valor de otro tipo vuelve al de fábrica")
	assert_eq(settings.get_value(&"sfx"), 30, "y el resto se lee")
	assert_eq(settings.save_settings(), OK, "guardar devuelve el resultado")
	assert_true(not FileAccess.file_exists(settings_path + ".tmp"), "sin temporales")
	DirAccess.rename_absolute(ProjectSettings.globalize_path(settings_path), ProjectSettings.globalize_path(settings_path + ".tmp"))
	settings.load_settings()
	assert_eq(settings.get_value(&"sfx"), 30, "si se cortó antes de renombrar, lee el temporal")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path + ".tmp"))
	_restore(settings)


## 11.223: Juego | Video en pestañas; LB/RB las cambian y el foco cae en el primer control de cada una.
func test_lb_rb_switch_tabs_and_focus_the_first_control() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var settings := _settings()
	var stack: Node = tree.root.get_node(^"MenuStack")
	var screen := OptionsScreen.open()
	await tree.process_frame
	await tree.process_frame
	var panel := screen.panel
	var press := func(action: StringName) -> void:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		tree.root.push_input(event)
	assert_eq(tree.root.gui_get_focus_owner(), panel.get_node(^"%lock_mantener"), "abre en Juego, en Fijar objetivo")
	assert_true(panel.get_node(^"%music").is_visible_in_tree() and not panel.get_node(^"%fullscreen").is_visible_in_tree(), "Juego tiene el audio y no el video")
	press.call(&"ui_tab_right")
	await tree.process_frame
	assert_eq(panel.tabs.current_tab, 1, "RB pasa a Video")
	assert_true(panel.get_node(^"%ssao").is_visible_in_tree() and not panel.get_node(^"%music").is_visible_in_tree(), "con Pantalla y Gráficos")
	assert_eq(tree.root.gui_get_focus_owner(), panel.get_node(^"%fullscreen"), "foco en Pantalla completa")
	press.call(&"ui_tab_right")
	await tree.process_frame
	assert_eq(panel.tabs.current_tab, 0, "y da la vuelta")
	press.call(&"ui_tab_left")
	await tree.process_frame
	assert_eq(panel.tabs.current_tab, 1, "LB vuelve a Video")
	assert_eq(tree.root.gui_get_focus_owner(), panel.get_node(^"%fullscreen"), "otra vez en el primero")
	while stack.is_open():
		stack.pop()
	_restore(settings)


## 15.19: un perfil pone todas las opciones gráficas; tocar una suelta lo deja en Personalizado.
func test_quality_profiles() -> void:
	var settings := _settings()
	assert_eq(settings.get_value(&"quality"), "", "la primera vez queda sin decidir hasta calibrar")
	var platform: QualityProfile = settings.PROFILES[settings.platform_profile()]
	for key in settings.GRAPHICS:
		assert_eq(settings.get_value(key), platform.get(key), "%s del perfil de la plataforma" % key)
	settings.apply_profile("bajo")
	settings.load_settings()
	assert_eq(settings.get_value(&"quality"), "bajo", "el perfil se guarda")
	for key in settings.GRAPHICS:
		assert_eq(settings.get_value(key), settings.PROFILES["bajo"].get(key), "%s de Bajo" % key)
	settings.set_value(&"ssao", true)
	assert_eq(settings.get_value(&"quality"), settings.CUSTOM, "una opción suelta: Personalizado")
	assert_eq(settings.get_value(&"ssao"), true, "con el ajuste del jugador")
	settings.set_value(&"ssao", false)
	assert_eq(settings.get_value(&"quality"), "bajo", "si vuelve a coincidir, es otra vez Bajo")
	_restore(settings)


func test_settings_from_before_profiles_keep_their_values() -> void:
	var settings := _settings()
	var cfg := ConfigFile.new()
	cfg.set_value("options", "sfx", 30)
	cfg.save(settings_path)
	settings.load_settings()
	assert_eq(settings.get_value(&"quality"), "alto", "los gráficos de fábrica son Alto, sin calibrar")
	cfg.set_value("options", "shadows", 1)
	cfg.save(settings_path)
	settings.load_settings()
	assert_eq(settings.get_value(&"quality"), settings.CUSTOM, "otros: Personalizado")
	assert_eq(settings.get_value(&"shadows"), 1, "y se respetan")
	_restore(settings)


func test_calibration_drops_one_step_when_slow() -> void:
	assert_eq(QualityCalibration.decide("medio", 50.0, 30.0), "bajo", "Medio a 50 ms con objetivo 30 fps: Bajo")
	assert_eq(QualityCalibration.decide("medio", 35.0, 30.0), "medio", "dentro del margen se queda")
	assert_eq(QualityCalibration.decide("alto", 25.0, 60.0), "medio", "Alto a 25 ms con objetivo 60 fps: Medio")
	assert_eq(QualityCalibration.decide("bajo", 90.0, 30.0), "bajo", "Bajo no baja más")
	assert_eq(QualityCalibration.median([3.0, 1.0, 2.0] as Array[float]), 2.0)


func test_plant_shadows_and_look_effects_follow_the_options() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var settings := _settings()
	var plant: Node3D = load("res://src/world/plants/tola.tscn").instantiate()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.compositor = Compositor.new()
	var ao := CompositorEffect.new()
	ao.set_script(settings.AO)
	var clouds := CompositorEffect.new()
	clouds.set_script(settings.CLOUDS)
	env.compositor.compositor_effects = [ao, clouds]
	tree.root.add_child(plant)
	tree.root.add_child(env)
	var meshes := plant.find_children("*", "GeometryInstance3D", true, false)
	assert_true(not meshes.is_empty(), "la tola tiene mallas")
	var casting: Array = meshes.map(func(m: GeometryInstance3D) -> int: return m.cast_shadow)
	settings.set_value(&"plant_shadows", false)
	assert_true(meshes.all(func(m: GeometryInstance3D) -> bool: return m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), "sin sombra de plantas")
	settings.set_value(&"plant_shadows", true)
	assert_eq(meshes.map(func(m: GeometryInstance3D) -> int: return m.cast_shadow), casting, "vuelve la de la escena")
	settings.set_value(&"look_effects", 1)
	assert_true(ao.enabled and not clouds.enabled, "1: sin nubes, con AO")
	settings.set_value(&"look_effects", 0)
	assert_true(not ao.enabled and not clouds.enabled, "0: tampoco AO")
	settings.set_value(&"look_effects", 2)
	assert_true(ao.enabled and clouds.enabled, "2: todos")
	plant.free()
	env.free()
	_restore(settings)


func test_the_profile_row_sets_the_graphics_rows() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var settings := _settings()
	settings.apply_profile("alto")
	var panel: Control = load("res://src/ui/menus/options_panel.tscn").instantiate()
	tree.root.add_child(panel)
	var quality := panel.find_child("quality", true, false) as OptionButton
	assert_eq(quality.selected, 2, "muestra Alto")
	quality.select(0)
	quality.item_selected.emit(0)
	assert_eq(settings.get_value(&"quality"), "bajo", "elegir Bajo pone el perfil")
	var render_scale := panel.find_child("render_scale", true, false) as OptionButton
	var shadows := panel.find_child("shadows", true, false) as OptionButton
	assert_eq(render_scale.get_selected_id(), settings.PROFILES["bajo"].render_scale, "la fila de resolución lo sigue")
	assert_eq(shadows.get_selected_id(), settings.PROFILES["bajo"].shadows, "y la de sombras")
	assert_eq((panel.find_child("ssao", true, false) as CheckBox).button_pressed, settings.PROFILES["bajo"].ssao, "y la del AO")
	shadows.select(shadows.get_item_index(1))
	shadows.item_selected.emit(shadows.get_item_index(1))
	assert_eq(quality.selected, 3, "una opción suelta muestra Personalizado")
	assert_eq(settings.get_value(&"shadows"), 1, "con el ajuste del jugador")
	assert_true(quality.is_item_disabled(3), "Personalizado no se elige")
	panel.free()
	_restore(settings)
