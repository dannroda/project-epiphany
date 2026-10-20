extends "res://tests/test_case.gd"
## La UI se arma en escenas: ningún script de src/ui crea Controls ni StyleBoxes por código.


func test_ui_scripts_do_not_build_controls() -> void:
	var bases := {}
	for entry in ProjectSettings.get_global_class_list():
		bases[entry["class"]] = entry["base"]
	var call := RegEx.create_from_string("\\b([A-Z]\\w*)\\.new\\(")
	var offenders: PackedStringArray = []
	for path in _scripts("res://src/ui"):
		var source := FileAccess.get_file_as_string(path)
		for found in call.search_all(source):
			var type := found.get_string(1)
			if _is_ui_type(type, bases):
				offenders.append("%s: %s.new()" % [path.get_file(), type])
	assert_eq(offenders, PackedStringArray(), "usar una escena .tscn")


func test_every_eye_is_the_logo_eye() -> void:
	var eye := load("res://assets/ui/logo/epiphany_eye.png")
	for pair in [["res://src/ui/menus/game_over.tscn", ^"Eye"], ["res://src/ui/title/language_select.tscn", ^"Eye"], ["res://src/flow/scene_flow.tscn", ^"Loading/Busy/Eye"]]:
		var root := (load(pair[0]) as PackedScene).instantiate()
		var node := root.get_node(pair[1]) as TextureRect
		assert_true(node != null and node.texture == eye, "%s usa el ojo del logo" % pair[0].get_file())
		root.free()


## Script que empuja → escena que empuja. Agregar acá cada pantalla nueva de la pila.
const PUSHED := {
	"res://src/ui/menus/game_over.gd": "res://src/ui/menus/game_over.tscn",
	"res://src/ui/controls/controls_screen.gd": "res://src/ui/controls/controls_screen.tscn",
	"res://src/ui/text_box/text_box.gd": "res://src/ui/text_box/text_box.tscn",
	"res://src/ui/title/file_select.gd": "res://src/ui/title/file_select.tscn",
	"res://src/ui/title/language_select.gd": "res://src/ui/title/language_select.tscn",
	"res://src/ui/title/scenario_list.gd": "res://src/ui/title/scenario_list.tscn",
	"res://src/ui/menus/options_screen.gd": "res://src/ui/menus/options_screen.tscn",
	"res://src/ui/menus/confirm_dialog.gd": "res://src/ui/menus/confirm_dialog.tscn",
	"res://player/states/item_get.gd": "res://src/ui/item_get/item_get.tscn",
	"res://src/world/technique_stone.gd": "res://src/ui/item_get/technique_learned.tscn",
	"res://src/ui/menus/menu_stack.gd": "res://src/ui/menus/pause_menu.tscn",
}


func test_every_screen_on_the_stack_is_a_ui_screen() -> void:
	var pushing: PackedStringArray = []
	for path in _scripts("res://src") + _scripts("res://player"):
		if path != "res://src/ui/menus/menu_stack.gd" and FileAccess.get_file_as_string(path).contains("MenuStack.push("):
			pushing.append(path)
	for path in pushing:
		assert_true(PUSHED.has(path), "%s empuja una pantalla: sumarla a PUSHED" % path.get_file())
	for scene: String in PUSHED.values() + ["res://src/ui/title/title_screen.tscn"]:
		var root := (load(scene) as PackedScene).instantiate()
		assert_true(root is UiScreen, "%s tiene una UiScreen de raíz" % scene.get_file())
		root.free()
	var pause := (load("res://src/ui/menus/pause_menu.tscn") as PackedScene).instantiate()
	for page in pause.get_node(^"%Pages").get_children():
		assert_true(page is PausePage, "la pestaña %s es una PausePage" % page.name)
	pause.free()


func _is_ui_type(type: StringName, bases: Dictionary) -> bool:
	while bases.has(type):
		type = bases[type]
	if not ClassDB.class_exists(type):
		return false
	return ClassDB.is_parent_class(type, &"Control") or ClassDB.is_parent_class(type, &"StyleBox")


func _scripts(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_scripts(dir.path_join(sub)))
	return found
