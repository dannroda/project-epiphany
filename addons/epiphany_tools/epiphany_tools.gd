@tool
extends EditorPlugin

const LogScript := preload("res://src/debug/log.gd")
const LogDebuggerPlugin := preload("debug/editor/log_debugger_plugin.gd")
const SaveInspector := preload("save_inspector/save_inspector.gd")
const SceneImport := preload("import/epi_scene_import.gd")
const WallTopsScript := preload("res://src/world/nav/wall_tops.gd")

const AutoLoads = {
	"Log": "res://src/debug/log.gd",
	"DebugOverlay": "res://src/debug/debug_overlay.tscn",
}

var _log_debugger: LogDebuggerPlugin
var _save_dock: EditorDock
var _scene_import: SceneImport


func _enable_plugin() -> void:
	for _singleton in AutoLoads:
		if not ProjectSettings.has_setting("autoload/" + _singleton):
			add_autoload_singleton(_singleton, AutoLoads[_singleton])


# Los autoloads quedan: el juego usa Log y DebugOverlay, y así recargar el plugin no los reordena.
func _disable_plugin() -> void:
	pass


func _enter_tree() -> void:
	_add_setting(LogScript.SETTING_LEVEL, LogScript.LEVEL_AUTO, PROPERTY_HINT_ENUM,
			"Auto (Debug en debug, Warning en release):-1,Debug:0,Info:1,Success:2,Warning:3,Error:4,None:5")
	_add_setting(LogScript.SETTING_CHANNELS, PackedStringArray(), PROPERTY_HINT_TYPE_STRING,
			"%d:" % TYPE_STRING)
	_log_debugger = LogDebuggerPlugin.new()
	add_debugger_plugin(_log_debugger)
	_save_dock = EditorDock.new()
	_save_dock.title = "Save Inspector"
	_save_dock.layout_key = "epiphany_save_inspector"
	_save_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_BL
	_save_dock.add_child(SaveInspector.new())
	add_dock(_save_dock)
	_scene_import = SceneImport.new()
	add_scene_post_import_plugin(_scene_import)
	WallTopsScript.register()
	if Engine.has_meta(&"editor_bridge"):
		_log_debugger.entry_received.connect(Engine.get_meta(&"editor_bridge").record_game_entry)


func _exit_tree() -> void:
	WallTopsScript.unregister()
	remove_scene_post_import_plugin(_scene_import)
	_scene_import = null
	remove_dock(_save_dock)
	_save_dock.queue_free()
	_save_dock = null
	remove_debugger_plugin(_log_debugger)
	_log_debugger = null


func _add_setting(setting: String, default: Variant, hint: PropertyHint, hint_string: String) -> void:
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, default)
	ProjectSettings.set_initial_value(setting, default)
	ProjectSettings.set_as_basic(setting, true)
	ProjectSettings.add_property_info({
		"name": setting, "type": typeof(default), "hint": hint, "hint_string": hint_string,
	})
