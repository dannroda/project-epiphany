@tool
extends Node

const LogSink := preload("../epiphany_tools/debug/runtime/log_sink.gd")
const PORT := 4713
const MAX_LOG := 500

var plugin: EditorPlugin

var _server := TCPServer.new()
var _clients: Array[Dictionary] = []
var _sink := LogSink.new()
var _log: Array[Dictionary] = []
var _seq := 0


var _next_listen_ms := 0


func _ready() -> void:
	OS.add_logger(_sink)


func _exit_tree() -> void:
	OS.remove_logger(_sink)
	_server.stop()
	for client in _clients:
		client.peer.disconnect_from_host()


func record_game_entry(level: int, channel: String, text: String, file: String, line: int, time: String) -> void:
	_record({ "source": "game", "level": level, "channel": channel, "text": text, "file": file, "line": line, "time": time })


func _record(entry: Dictionary) -> void:
	_seq += 1
	entry.seq = _seq
	_log.append(entry)
	if _log.size() > MAX_LOG:
		_log.pop_front()


func _listen() -> void:
	if _server.is_listening() or Time.get_ticks_msec() < _next_listen_ms:
		return
	if _server.listen(PORT, "127.0.0.1") != OK:
		_next_listen_ms = Time.get_ticks_msec() + 1000


func _process(_delta: float) -> void:
	_listen()
	for e in _sink.drain():
		var level := 4 if e.error else (3 if e.warning else 1)
		_record({ "source": "editor", "level": level, "channel": "editor", "text": e.text, "file": e.file, "line": e.line,
			"time": Time.get_time_string_from_system() })

	while _server.is_connection_available():
		_clients.append({ "peer": _server.take_connection(), "data": PackedByteArray(), "pending": Callable() })

	for client in _clients.duplicate():
		var peer: StreamPeerTCP = client.peer
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_clients.erase(client)
			continue
		if client.pending.is_valid():
			var result: Variant = client.pending.call()
			if result != null:
				_respond(client, 200, result)
			continue
		var available := peer.get_available_bytes()
		if available > 0:
			client.data.append_array(peer.get_data(available)[1])
		var request := _parse(client.data)
		if request.is_empty():
			continue
		var result: Variant = _handle(request)
		if result is Callable:
			client.pending = result
		elif result == null:
			_respond(client, 404, { "error": "comando desconocido: %s" % request.path })
		else:
			_respond(client, 200, result)


func _parse(data: PackedByteArray) -> Dictionary:
	var text := data.get_string_from_utf8()
	var header_end := text.find("\r\n\r\n")
	if header_end == -1:
		return {}
	var lines := text.substr(0, header_end).split("\r\n")
	var request_line := lines[0].split(" ")
	if request_line.size() < 2:
		return {}
	var length := 0
	for line in lines:
		if line.to_lower().begins_with("content-length:"):
			length = line.get_slice(":", 1).strip_edges().to_int()
	var body_bytes := data.slice(text.substr(0, header_end + 4).to_utf8_buffer().size())
	if body_bytes.size() < length:
		return {}
	var target := request_line[1]
	var query := {}
	if "?" in target:
		for pair in target.get_slice("?", 1).split("&", false):
			query[pair.get_slice("=", 0).uri_decode()] = pair.get_slice("=", 1).uri_decode()
	var body: Variant = JSON.parse_string(body_bytes.slice(0, length).get_string_from_utf8()) if length > 0 else null
	if body is Dictionary:
		query.merge(body, true)
	return { "method": request_line[0], "path": target.get_slice("?", 0), "args": query }


func _handle(request: Dictionary) -> Variant:
	var args: Dictionary = request.args
	match request.path:
		"/ping":
			return { "ok": true, "project": ProjectSettings.get_setting("application/config/name"),
				"playing": EditorInterface.is_playing_scene() }
		"/scan":
			return _scan()
		"/status":
			return { "playing": EditorInterface.is_playing_scene(), "scene": EditorInterface.get_playing_scene(),
				"edited_scene": _edited_scene_path() }
		"/play":
			if args.has("scene"):
				EditorInterface.play_custom_scene(args.scene)
			else:
				EditorInterface.play_main_scene()
			return { "ok": true }
		"/stop":
			EditorInterface.stop_playing_scene()
			return { "ok": true }
		"/log":
			var since := int(args.get("since", 0))
			return { "seq": _seq, "entries": _log.filter(func(e: Dictionary) -> bool: return e.seq > since) }
		"/open":
			return _open(args.get("path", ""), int(args.get("line", -1)))
		"/save":
			EditorInterface.save_all_scenes()
			return { "ok": true }
		"/autoload":
			plugin.add_autoload_singleton(args.name, args.path)
			return { "ok": ProjectSettings.has_setting("autoload/" + args.name) }
		"/plugin":
			EditorInterface.set_plugin_enabled(args.name, str(args.get("enabled", "true")) == "true")
			return { "ok": true, "enabled": EditorInterface.is_plugin_enabled(args.name) }
		"/reload_plugin":
			return _reload_plugin(args.name)
		"/run":
			return _run(args.get("path", ""), args)
		"/reload_scene":
			EditorInterface.reload_scene_from_path(args.path)
			return { "ok": true }
		"/setting":
			ProjectSettings.set_setting(args.name, args.get("value"))
			return { "ok": ProjectSettings.save() == OK }
	return null


func _scan() -> Callable:
	var filesystem := EditorInterface.get_resource_filesystem()
	var state := { "classes_updated": false, "done_frame": -1 }
	filesystem.script_classes_updated.connect(func() -> void: state.classes_updated = true, CONNECT_ONE_SHOT)
	filesystem.scan()
	var start := Engine.get_process_frames()
	return func() -> Variant:
		var frame := Engine.get_process_frames()
		if frame - start < 2 or filesystem.is_scanning():
			return null
		if state.done_frame == -1:
			state.done_frame = frame
		if not state.classes_updated and frame - state.done_frame < 30:
			return null
		return { "ok": true, "classes_updated": state.classes_updated }


## Corre `run(plugin, args)` de un script @tool (ruta res:// o absoluta) dentro del editor.
func _run(path: String, args: Dictionary) -> Dictionary:
	var script := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Script
	if script == null or not script.can_instantiate():
		return { "ok": false, "error": "no se pudo cargar %s" % path }
	var instance: Object = script.new()
	if not instance.has_method(&"run"):
		return { "ok": false, "error": "%s no tiene run(plugin, args)" % path }
	var result: Variant = instance.call(&"run", plugin, args)
	return { "ok": true, "result": result }


func _reload_plugin(plugin_name: String) -> Callable:
	EditorInterface.set_plugin_enabled(plugin_name, false)
	var start := Engine.get_process_frames()
	return func() -> Variant:
		if Engine.get_process_frames() - start < 2:
			return null
		var reloaded := _reload_scripts("res://addons".path_join(plugin_name))
		EditorInterface.set_plugin_enabled(plugin_name, true)
		return { "ok": EditorInterface.is_plugin_enabled(plugin_name), "reloaded": reloaded }


func _reload_scripts(dir: String) -> PackedStringArray:
	var reloaded := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir):
		reloaded.append_array(_reload_scripts(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		var path := dir.path_join(file)
		if file.get_extension() != "gd" or not ResourceLoader.has_cached(path):
			continue
		var script := load(path) as GDScript
		var source := FileAccess.get_file_as_string(path)
		if script.source_code != source:
			script.source_code = source
			script.reload(true)
			reloaded.append(path)
	return reloaded


func _open(path: String, line: int) -> Dictionary:
	if not ResourceLoader.exists(path):
		return { "ok": false, "error": "no existe: %s" % path }
	match path.get_extension():
		"gd":
			EditorInterface.edit_script(load(path), maxi(line, 1), 1)
			EditorInterface.set_main_screen_editor("Script")
		"tscn", "scn":
			EditorInterface.open_scene_from_path(path)
		_:
			EditorInterface.edit_resource(load(path))
	return { "ok": true }


func _edited_scene_path() -> String:
	var root := EditorInterface.get_edited_scene_root()
	return root.scene_file_path if root else ""


func _respond(client: Dictionary, status: int, body: Variant) -> void:
	var payload := JSON.stringify(body).to_utf8_buffer()
	var head := "HTTP/1.1 %d %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [
		status, "OK" if status == 200 else "Not Found", payload.size()]
	var peer: StreamPeerTCP = client.peer
	peer.put_data(head.to_utf8_buffer() + payload)
	peer.disconnect_from_host()
	_clients.erase(client)
