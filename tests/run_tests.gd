# godot --headless --path . --script res://tests/run_tests.gd [-- --jobs=N --only=test_a.gd,test_b.gd]
## Reparte los test_*.gd entre varios procesos headless (por defecto, los núcleos, hasta 4), parejos según cuánto
## tardó cada archivo la última vez, y junta los resultados. Cada proceso tiene sus partidas y opciones en user://.
## Los procesos corren con --fixed-fps 60: cada frame avanza 1/60 s de juego aunque la máquina esté cargada.
## Lo que imprime cada proceso queda entero en user://tests/<copia>/test_logs/. Cada copia del proyecto (los worktrees comparten
## user://) tiene su carpeta, así dos copias pueden correr tests a la vez.
extends SceneTree

const DIR := "res://tests"
const TestCase := preload("res://tests/test_case.gd")
## La carpeta de esta copia del proyecto.
static var ROOT := "user://tests/%s/" % ProjectSettings.globalize_path("res://").md5_text().left(8)
static var TIMES := ROOT + "test_times.cfg"
static var LOGS := ROOT + "test_logs/"
const MAX_JOBS := 4
## Lo que se supone que tarda un archivo que nunca se midió (s).
const UNKNOWN_TIME := 20.0
## Un proceso que pasa este tiempo sin terminar un test se da por colgado: se mata y cuenta como falla (s).
const STALL_SECONDS := 300.0


## Junta los errores de script (los que cortan la función que corría) para fallar el test en curso.
class ScriptErrors extends Logger:
	var _mutex := Mutex.new()
	var _seen := PackedStringArray()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_SCRIPT:
			return
		_mutex.lock()
		_seen.append("%s:%d %s" % [file.get_file(), line, rationale if not rationale.is_empty() else code])
		_mutex.unlock()

	func take() -> PackedStringArray:
		_mutex.lock()
		var seen := _seen
		_seen = PackedStringArray()
		_mutex.unlock()
		return seen


func _initialize() -> void:
	var args := _args()
	if args.has("worker"):
		await _work(int(args.worker), (args.files as String).split(","))
	else:
		await _coordinate(args)


func _args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", true, 1)
		args[pair[0]] = pair[1] if pair.size() > 1 else ""
	return args


func _test_files(only: String) -> PackedStringArray:
	var files := PackedStringArray()
	for file in DirAccess.get_files_at(DIR):
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_case.gd":
			files.append(file)
	if not only.is_empty():
		var wanted := only.split(",")
		files = PackedStringArray(Array(wanted).filter(func(file: String) -> bool: return files.has(file)))
	return files


func _coordinate(args: Dictionary) -> void:
	var start := Time.get_ticks_msec()
	var files := _test_files(args.get("only", ""))
	var jobs := clampi(int(args.get("jobs", mini(OS.get_processor_count(), MAX_JOBS))), 1, maxi(files.size(), 1))
	var times := ConfigFile.new()
	times.load(TIMES)
	var result := await _run_in_processes(_split(files, jobs, times))
	for file: String in result.times:
		times.set_value("times", file, result.times[file])
	times.save(TIMES)
	for failure: String in result.failures:
		printerr(failure)
	print("%d tests, %d fallos (%d procesos, %.0f s)" % [result.total, result.failures.size(), jobs, (Time.get_ticks_msec() - start) / 1000.0])
	quit(1 if not result.failures.is_empty() else 0)


## Reparto goloso: el archivo más largo que falta va al proceso con menos trabajo.
func _split(files: PackedStringArray, jobs: int, times: ConfigFile) -> Array[PackedStringArray]:
	var sorted := Array(files)
	var cost := func(file: String) -> float: return times.get_value("times", file, UNKNOWN_TIME)
	sorted.sort_custom(func(a: String, b: String) -> bool: return cost.call(a) > cost.call(b))
	var buckets: Array[PackedStringArray] = []
	var load_of: Array[float] = []
	for i in jobs:
		buckets.append(PackedStringArray())
		load_of.append(0.0)
	for file: String in sorted:
		var lightest := load_of.find(load_of.min())
		buckets[lightest].append(file)
		load_of[lightest] += cost.call(file)
	return buckets


func _run_in_processes(buckets: Array[PackedStringArray]) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(LOGS)
	var mutex := Mutex.new()
	var workers := []
	for i in buckets.size():
		var pipes := OS.execute_with_pipe(OS.get_executable_path(), ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/run_tests.gd", "--", "--worker=%d" % i, "--files=" + ",".join(buckets[i])])
		var log_file := FileAccess.open(LOGS + "worker_%d.log" % i, FileAccess.WRITE)
		log_file.store_line("# pid %d: %s" % [pipes.pid, ", ".join(buckets[i])])
		var worker := {pid = pipes.pid, threads = [], log_file = log_file, files = buckets[i], progress_ms = Time.get_ticks_msec(), last_test = "", hung = false}
		for pipe: FileAccess in [pipes.stdio, pipes.stderr]:
			var thread := Thread.new()
			thread.start(_pump.bind(pipe, worker, mutex))
			worker.threads.append(thread)
		workers.append(worker)
	while workers.any(func(worker: Dictionary) -> bool: return not worker.hung and OS.is_process_running(worker.pid)):
		await create_timer(0.5).timeout
		mutex.lock()
		for worker: Dictionary in workers:
			if not worker.hung and OS.is_process_running(worker.pid) and Time.get_ticks_msec() - worker.progress_ms > STALL_SECONDS * 1000.0:
				worker.hung = true
				OS.kill(worker.pid)
		mutex.unlock()
	var merged := {total = 0, failures = PackedStringArray(), times = {}}
	for i in workers.size():
		if workers[i].hung:
			merged.total += 1
			merged.failures.append("el proceso %d se colgó %d s después de %s; se mató (%s)" % [i, STALL_SECONDS, workers[i].last_test if workers[i].last_test else "arrancar", ", ".join(workers[i].files)])
		for thread: Thread in workers[i].threads:
			thread.wait_to_finish()
		workers[i].log_file.close()
		var result := ConfigFile.new()
		if result.load(_result_path(i)) != OK:
			if workers[i].hung:
				continue
			merged.total += 1
			merged.failures.append("el proceso %d terminó sin resultados (salió con %d; %s); ver %s" % [i, OS.get_process_exit_code(workers[i].pid), ", ".join(workers[i].files), ProjectSettings.globalize_path(LOGS + "worker_%d.log" % i)])
			continue
		merged.total += result.get_value("result", "total")
		merged.failures.append_array(result.get_value("result", "failures"))
		merged.times.merge(result.get_value("result", "times"))
		DirAccess.remove_absolute(_result_path(i))
	return merged


## Copia todo lo que imprime un proceso a su log y muestra solo las líneas de resultado.
func _pump(pipe: FileAccess, worker: Dictionary, mutex: Mutex) -> void:
	while true:
		var line := pipe.get_line()
		if line.is_empty() and (pipe.eof_reached() or worker.hung or not OS.is_process_running(worker.pid)):
			break
		mutex.lock()
		worker.log_file.store_line(line)
		if line.begins_with("ok") or line.begins_with("FALLA"):
			print(line)
			worker.progress_ms = Time.get_ticks_msec()
			worker.last_test = line.substr(5).strip_edges()
		mutex.unlock()


func _result_path(index: int) -> String:
	return ROOT + "test_result_%d.cfg" % index


func _work(index: int, files: PackedStringArray) -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	TestCase.saves_dir = ROOT + "test_saves_%d/" % index
	TestCase.settings_path = ROOT + "test_settings_%d.cfg" % index
	TestCase.tmp_dir = ROOT + "tests_tmp_%d" % index
	var result := await _run_here(files)
	var out := ConfigFile.new()
	for key: String in result:
		out.set_value("result", key, result[key])
	out.save(_result_path(index))
	quit(0)


func _run_here(files: PackedStringArray) -> Dictionary:
	await process_frame
	root.get_node(^"SaveManager").save_dir = TestCase.saves_dir
	root.get_node(^"Settings").path = TestCase.settings_path
	root.get_node(^"Settings").set_value(&"language", "es")
	var total := 0
	var failures := PackedStringArray()
	var times := {}
	var errors := ScriptErrors.new()
	OS.add_logger(errors)
	for file in files:
		var started := Time.get_ticks_msec()
		var script: GDScript = load(DIR.path_join(file))
		if script == null or not script.can_instantiate():
			total += 1
			failures.append("%s: no compila" % file.get_basename())
			print("FALLA %s (no compila)" % file.get_basename())
			continue
		var suite: RefCounted = script.new()
		for method in suite.get_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			total += 1
			suite.current_test = "%s › %s" % [file.get_basename(), test_name]
			var before: int = suite.failures.size()
			suite.assertions = 0
			load("res://src/tools/top_down_camera.gd").set(&"unlock_reveals", false)
			errors.take()
			await suite.call(test_name)
			for action in InputMap.get_actions():
				Input.action_release(action)
			var seen := errors.take()
			if not seen.is_empty():
				suite.failures.append("%s: error de script (%d): %s" % [suite.current_test, seen.size(), seen[0]])
			if suite.assertions == 0:
				suite.failures.append("%s: no llegó a verificar nada (¿se cortó por un error?)" % suite.current_test)
			print("%s %s" % ["ok  " if suite.failures.size() == before else "FALLA", suite.current_test])
		failures.append_array(suite.failures)
		times[file] = (Time.get_ticks_msec() - started) / 1000.0
	OS.remove_logger(errors)
	return {total = total, failures = failures, times = times}
