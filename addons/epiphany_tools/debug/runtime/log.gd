# Autoload
extends Node

enum Level { DEBUG, INFO, SUCCESS, WARNING, ERROR, NONE }


const SETTING_LEVEL := "epiphany/log/level"
const SETTING_CHANNELS := "epiphany/log/channels"

const ENGINE := &"engine"
const COLORS := { Level.DEBUG: "wheat", Level.INFO: "cyan", Level.SUCCESS: "green" }

var level: Level = Level.DEBUG
var _channels: Dictionary[StringName, bool] = {}

#var _sink := LogSink.new()

func _ready() -> void:
	level = ProjectSettings.get_setting(SETTING_LEVEL, Level.DEBUG if OS.is_debug_build() else Level.WARNING)
	for channel in ProjectSettings.get_setting(SETTING_CHANNELS, PackedStringArray()):
		_channels[StringName(channel)] = true


func debug(channel: StringName, ...args: Array) -> void:
	_print(Level.DEBUG, channel, args)


func info(channel: StringName, ...args: Array) -> void:
	_print(Level.INFO, channel, args)


func success(channel: StringName, ...args: Array) -> void:
	_print(Level.SUCCESS, channel, args)


func warning(channel: StringName, ...args: Array) -> void:
	if level <= Level.WARNING:
		push_warning("[%s] %s" % [channel, _join(args)])


func error(channel: StringName, ...args: Array) -> void:
	if level <= Level.ERROR:
		push_error("[%s] %s" % [channel, _join(args)])


func is_enabled(lvl: Level, channel: StringName) -> bool:
	return lvl >= level and (_channels.is_empty() or _channels.has(channel))


func _print(lvl: Level, channel: StringName, args: Array) -> void:
	if not is_enabled(lvl, channel):
		return
	print_rich("[color=%s][b][%s][/b][/color] [color=gray]%s[/color] %s" % [
		COLORS[lvl], Level.find_key(lvl), channel, _join(args)
		])


func _join(args: Array) -> String:
	return " ".join(args.map(func(a: Variant) -> String: return str(a)))
