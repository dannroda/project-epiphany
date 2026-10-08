@tool
extends EditorDebuggerPlugin

signal entry_received(level: int, channel: String, text: String, file: String, line: int, time: String)

const LogPanel := preload("log_panel.gd")
const CAPTURE := "epiphany_log"

var _panels: Dictionary[int, LogPanel] = {}


func _has_capture(capture: String) -> bool:
	return capture == CAPTURE


func _setup_session(session_id: int) -> void:
	var session := get_session(session_id)
	var panel := LogPanel.new()
	panel.name = "Log"
	panel.filter_changed.connect(func(level: int, channels: PackedStringArray) -> void:
		if session.is_active():
			session.send_message(CAPTURE + ":filter", [level, channels]))
	session.started.connect(func() -> void:
		panel.clear_entries()
		session.send_message(CAPTURE + ":filter", panel.get_filter()))
	session.add_session_tab(panel)
	_panels[session_id] = panel


func _capture(message: String, data: Array, session_id: int) -> bool:
	if message == CAPTURE + ":entry" and _panels.has(session_id):
		_panels[session_id].add_entry.callv(data)
		entry_received.emit.callv(data)
		return true
	return false
