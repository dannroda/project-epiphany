@tool
extends EditorPlugin

const AutoLoads = {
	"Log": "debug/runtime/log.gd"
}

const Classes = {
	"LogSink": "debug/runtime/log_sink.gd"
}

const Settings = {
	
}

var _base_dir:String

func _enable_plugin() -> void:
	for _singleton in AutoLoads:
		add_autoload_singleton(_singleton, AutoLoads[_singleton])
	
	for _class in Classes:
		var _path = "/".join([_base_dir,Classes[_class]])
		var _script = load(_path)
		printt("path:", _path)
		printt(type_string(typeof(_script.get_script())))
		printt(_script.get_global_name(), _script.get_base_script())
		#add_custom_type(_class, )
	

func _disable_plugin() -> void:
	for _singleton in AutoLoads:
		ProjectSettings.set_setting("autoload/" + _singleton, null) # Workaroud (https://github.com/godotengine/godot/issues/124137)
		#remove_autoload_singleton(_singleton) 

func _enter_tree() -> void:
	_base_dir = get_script().resource_path.get_base_dir()


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
