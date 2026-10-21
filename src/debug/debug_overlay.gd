# Autoload
extends CanvasLayer

const LogScript := preload("log.gd")

const ACTION := &"debug_overlay"
const MAX_ISSUES := 5

var _values: Dictionary[String, Variant] = {}
var _issues: PackedStringArray = []
@onready var _label: Label = %Label


func _ready() -> void:
	var log_node := get_node_or_null(^"/root/Log")
	if log_node:
		log_node.entry_logged.connect(_on_entry_logged)


func watch(key: String, value: Variant) -> void:
	_values[key] = value


func unwatch(key: String) -> void:
	_values.erase(key)


func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action(ACTION) and event.is_action_pressed(ACTION):
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	var lines := PackedStringArray()
	var keys := _values.keys()
	keys.sort()
	for key: String in keys:
		lines.append("%s: %s" % [key, _values[key]])
	if not _issues.is_empty():
		lines.append("")
		lines.append_array(_issues)
	_label.text = "\n".join(lines)


func _on_entry_logged(level: int, channel: StringName, text: String) -> void:
	if level < LogScript.Level.WARNING:
		return
	_issues.append("%s [%s] %s" % ["E" if level >= LogScript.Level.ERROR else "W", channel, text.get_slice("\n", 0)])
	if _issues.size() > MAX_ISSUES:
		_issues.remove_at(0)
