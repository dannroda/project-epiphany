# godot --headless --path . --script res://tests/run_tests.gd [-- --jobs=N --only=test_a.gd,test_b.gd]
## Reparte los test_*.gd entre varios procesos headless (por defecto, los núcleos, hasta 4), parejos según cuánto
## tardó cada archivo la última vez, y junta los resultados. Cada proceso tiene sus partidas y opciones en user://.
## Los procesos corren con --fixed-fps 60: cada frame avanza 1/60 s de juego aunque la máquina esté cargada.
## Lo que imprime cada proceso queda entero en user://test_logs/.
extends SceneTree

const DIR := "res://tests"
const TestCase := preload("res://tests/test_case.gd")
const TIMES := "user://test_times.cfg"
const LOGS := "user://test_logs/"
const MAX_JOBS := 4
## Lo que se supone que tarda un archivo que nunca se midió (s).
const UNKNOWN_TIME := 20.0


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
		var threads: Array[Thread] = []
		for pipe: FileAccess in [pipes.stdio, pipes.stderr]:
			var thread := Thread.new()
			thread.start(_pump.bind(pipe, pipes.pid, log_file, mutex))
			threads.append(thread)
		workers.append({pid = pipes.pid, threads = threads, log_file = log_file, files = buckets[i]})
	while workers.any(func(worker: Dictionary) -> bool: return OS.is_process_running(worker.pid)):
		await create_timer(0.5).timeout
	var merged := {total = 0, failures = PackedStringArray(), times = {}}
	for i in workers.size():
		for thread: Thread in workers[i].threads:
			thread.wait_to_finish()
		workers[i].log_file.close()
		var result := ConfigFile.new()
		if result.load(_result_path(i)) != OK:
			merged.total += 1
			merged.failures.append("el proceso %d terminó sin resultados (salió con %d; %s); ver %s" % [i, OS.get_process_exit_code(workers[i].pid), ", ".join(workers[i].files), ProjectSettings.globalize_path(LOGS + "worker_%d.log" % i)])
			continue
		merged.total += result.get_value("result", "total")
		merged.failures.append_array(result.get_value("result", "failures"))
		merged.times.merge(result.get_value("result", "times"))
		DirAccess.remove_absolute(_result_path(i))
	return merged


## Copia todo lo que imprime un proceso a su log y muestra solo las líneas de resultado.
func _pump(pipe: FileAccess, pid: int, log_file: FileAccess, mutex: Mutex) -> void:
	while true:
		var line := pipe.get_line()
		if line.is_empty() and (pipe.eof_reached() or not OS.is_process_running(pid)):
			break
		mutex.lock()
		log_file.store_line(line)
		if line.begins_with("ok") or line.begins_with("FALLA"):
			print(line)
		mutex.unlock()


func _result_path(index: int) -> String:
	return "user://test_result_%d.cfg" % index


func _work(index: int, files: PackedStringArray) -> void:
	TestCase.saves_dir = "user://test_saves_%d/" % index
	TestCase.settings_path = "user://test_settings_%d.cfg" % index
	TestCase.tmp_dir = "user://tests_tmp_%d" % index
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
			await suite.call(test_name)
			for action in InputMap.get_actions():
				Input.action_release(action)
			if suite.assertions == 0:
				suite.failures.append("%s: no llegó a verificar nada (¿se cortó por un error?)" % suite.current_test)
			print("%s %s" % ["ok  " if suite.failures.size() == before else "FALLA", suite.current_test])
		failures.append_array(suite.failures)
		times[file] = (Time.get_ticks_msec() - started) / 1000.0
	return {total = total, failures = failures, times = times}
