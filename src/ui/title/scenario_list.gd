class_name ScenarioList
extends UiScreen
## Debug: lista de escenarios guardados (debug/scenarios) para cargar uno desde el título.

signal chosen(scenario: String)

const SCENE_PATH := "res://src/ui/title/scenario_list.tscn"
const ITEM := preload("res://src/ui/menus/menu_item_small.tscn")

@onready var list: VBoxContainer = %List


static func open() -> ScenarioList:
	var screen: ScenarioList = load(SCENE_PATH).instantiate()
	MenuStack.push(screen)
	return screen


func _ready() -> void:
	for file in DirAccess.get_files_at(SaveManager.SCENARIO_DIR):
		if not file.ends_with(".cfg"):
			continue
		var item: Button = ITEM.instantiate()
		item.text = file.get_basename()
		item.pressed.connect(func() -> void: chosen.emit(file.get_basename()))
		list.add_child(item)


func focus_default() -> void:
	if list.get_child_count() > 0:
		(list.get_child(0) as Control).grab_focus()
