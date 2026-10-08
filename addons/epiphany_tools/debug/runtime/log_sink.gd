extends Logger
# Se llama desde cualquier hilo: no usar print ni push_error.

var skip_main_thread := false

var _mutex := Mutex.new()
var _queue: Array[Dictionary] = []


func _log_message(message: String, error: bool) -> void:
	if _is_own():
		return
	_push(message.strip_edges(false, true), "", 0, error, false)


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	if _is_own():
		return
	for backtrace in script_backtraces:
		if not backtrace.is_empty():
			file = backtrace.get_frame_file(0)
			line = backtrace.get_frame_line(0)
			break
	var text := rationale if not rationale.is_empty() else code
	var warning := error_type == ERROR_TYPE_WARNING
	_push(text, file, line, not warning, warning)


func drain() -> Array[Dictionary]:
	_mutex.lock()
	var entries := _queue
	_queue = []
	_mutex.unlock()
	return entries


func _is_own() -> bool:
	return skip_main_thread and OS.get_thread_caller_id() == OS.get_main_thread_id()


func _push(text: String, file: String, line: int, error: bool, warning: bool) -> void:
	_mutex.lock()
	_queue.append({ "text": text, "file": file, "line": line, "error": error, "warning": warning })
	_mutex.unlock()
