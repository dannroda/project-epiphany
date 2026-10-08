@tool
extends EditorPlugin

const EditorBridge := preload("editor_bridge.gd")

var _bridge: EditorBridge


func _enter_tree() -> void:
	_bridge = EditorBridge.new()
	_bridge.plugin = self
	add_child(_bridge)
	Engine.set_meta(&"editor_bridge", _bridge)


func _exit_tree() -> void:
	Engine.remove_meta(&"editor_bridge")
	_bridge.queue_free()
	_bridge = null
