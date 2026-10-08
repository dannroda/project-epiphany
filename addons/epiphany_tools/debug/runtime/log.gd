# Autoload
extends Node

signal entry_logged(level: Level, channel: StringName, text: String)

enum Level { DEBUG, INFO, SUCCESS, WARNING, ERROR, NONE }

const LogSink := preload("log_sink.gd")

const SETTING_LEVEL := "epiphany/log/level"
const SETTING_CHANNELS := "epiphany/log/channels"
const LEVEL_AUTO := -1

const CAPTURE := &"epiphany_log"
const ENGINE := &"engine"
const COLORS := { Level.DEBUG: "wheat", Level.INFO: "cyan", Level.SUCCESS: "green" }

var level: Level = Level.DEBUG
var channels: Dictionary[StringName, bool] = {}

var _sink := LogSink.new()


func _init() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	OS.add_logger(_sink)


func _ready() -> void:
	var lvl: int = ProjectSettings.get_setting(SETTING_LEVEL, LEVEL_AUTO)
	if lvl == LEVEL_AUTO:
		lvl = Level.DEBUG if OS.is_debug_build() else Level.WARNING
	level = lvl as Level
	set_channels(ProjectSettings.get_setting(SETTING_CHANNELS, PackedStringArray()))
	if EngineDebugger.is_active():
		EngineDebugger.register_message_capture(CAPTURE, _on_editor_message)


func _exit_tree() -> void:
	OS.remove_logger(_sink)
	if EngineDebugger.has_capture(CAPTURE):
		EngineDebugger.unregister_message_capture(CAPTURE)


func debug(channel: StringName, ...args: Array) -> void:
	_log(Level.DEBUG, channel, args)


func info(channel: StringName, ...args: Array) -> void:
	_log(Level.INFO, channel, args)


func success(channel: StringName, ...args: Array) -> void:
	_log(Level.SUCCESS, channel, args)


func warning(channel: StringName, ...args: Array) -> void:
	_log(Level.WARNING, channel, args)


func error(channel: StringName, ...args: Array) -> void:
	_log(Level.ERROR, channel, args)


func is_enabled(lvl: Level, channel: StringName) -> bool:
	return lvl >= level and (channels.is_empty() or channels.has(channel))


func set_channels(list: PackedStringArray) -> void:
	channels.clear()
	for channel in list:
		channels[StringName(channel)] = true


func _log(lvl: Level, channel: StringName, args: Array) -> void:
	if not is_enabled(lvl, channel):
		return
	var text := " ".join(args.map(func(a: Variant) -> String: return str(a)))
	var caller := _caller()

	_sink.skip_main_thread = true
	match lvl:
		Level.WARNING:
			push_warning("[%s] %s" % [channel, text])
		Level.ERROR:
			push_error("[%s] %s" % [channel, text])
		_:
			print_rich("[color=%s][b][%s][/b][/color] [color=%s][%s][/color] %s" % [
				COLORS[lvl], Level.find_key(lvl), _channel_color(channel), channel, text
				])
	_sink.skip_main_thread = false

	_emit(lvl, channel, text, caller.source, caller.line)


func _channel_color(channel: StringName) -> String:
	return Color.from_hsv((absi(hash(channel)) % 360) / 360.0, 0.45, 1.0).to_html(false)


func _process(_delta: float) -> void:
	for entry in _sink.drain():
		var lvl := Level.INFO
		if entry.error:
			lvl = Level.ERROR
		elif entry.warning:
			lvl = Level.WARNING
		if is_enabled(lvl, ENGINE):
			_emit(lvl, ENGINE, entry.text, entry.file, entry.line)


func _emit(lvl: Level, channel: StringName, text: String, file: String, line: int) -> void:
	entry_logged.emit(lvl, channel, text)
	if EngineDebugger.is_active():
		EngineDebugger.send_message("epiphany_log:entry", [
			lvl, channel, text, file, line, Time.get_time_string_from_system()
			])


func _caller() -> Dictionary:
	var stack := get_stack()
	return stack[3] if stack.size() > 3 else { "source": "", "line": 0 }


func _on_editor_message(message: String, data: Array) -> bool:
	if message == "filter":
		level = data[0]
		set_channels(data[1])
		return true
	return false
