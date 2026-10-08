@tool
extends EditorPlugin

const LogScript := preload("debug/runtime/log.gd")
const LogDebuggerPlugin := preload("debug/editor/log_debugger_plugin.gd")

const AutoLoads = {
	"Log": "debug/runtime/log.gd",
	"DebugOverlay": "debug/runtime/debug_overlay.gd",
}

var _log_debugger: LogDebuggerPlugin


func _enable_plugin() -> void:
	for _singleton in AutoLoads:
		add_autoload_singleton(_singleton, AutoLoads[_singleton])


func _disable_plugin() -> void:
	for _singleton in AutoLoads:
		ProjectSettings.set_setting("autoload/" + _singleton, null) # Workaroud (https://github.com/godotengine/godot/issues/124137)
		#remove_autoload_singleton(_singleton)


func _enter_tree() -> void:
	_add_setting(LogScript.SETTING_LEVEL, LogScript.LEVEL_AUTO, PROPERTY_HINT_ENUM,
			"Auto (Debug en debug, Warning en release):-1,Debug:0,Info:1,Success:2,Warning:3,Error:4,None:5")
	_add_setting(LogScript.SETTING_CHANNELS, PackedStringArray(), PROPERTY_HINT_TYPE_STRING,
			"%d:" % TYPE_STRING)
	_log_debugger = LogDebuggerPlugin.new()
	add_debugger_plugin(_log_debugger)
	if Engine.has_meta(&"editor_bridge"):
		_log_debugger.entry_received.connect(Engine.get_meta(&"editor_bridge").record_game_entry)


func _exit_tree() -> void:
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
