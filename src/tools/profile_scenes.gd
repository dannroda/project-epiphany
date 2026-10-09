# godot --path . --resolution 1280x720 --script res://src/tools/profile_scenes.gd
extends SceneTree
## Mide las escenas más pesadas (en ventana: headless no renderiza) y compara contra el presupuesto de frame.

const BUDGET_MS := 16.6
const SECONDS := 6.0


func _initialize() -> void:
	await process_frame
	var saves: Node = root.get_node(^"SaveManager")
	await _measure("overworld · pradera con pasto", func() -> void:
		await saves.load_scenario("start")
		get_first_node_in_group(&"player").global_position = Vector3(0, 0, 2))
	await _measure("templo · arena con oleadas", func() -> void:
		await saves.load_scenario("dungeon_no_bow")
		get_first_node_in_group(&"player").global_position = Vector3(48, 0, 37))
	await _measure("templo · antesala (doom 0.9)", func() -> void:
		await saves.load_scenario("pre_boss"))
	quit()


func _measure(label: String, setup: Callable) -> void:
	await setup.call()
	await create_timer(1.5).timeout
	var frames := []
	var process := []
	var physics := []
	var draws := []
	var until := Time.get_ticks_msec() + int(SECONDS * 1000.0)
	var last := Time.get_ticks_usec()
	while Time.get_ticks_msec() < until:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	frames.sort()
	var p95: float = frames[int(frames.size() * 0.95)]
	print("%s: frame medio %.1f ms, p95 %.1f ms, peor %.1f ms · process %.2f ms · physics %.2f ms · draw calls %d · objetos %d · enemigos %d · %s" % [
		label, _avg(frames), p95, frames.back(), _avg(process), _avg(physics), int(_avg(draws)),
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_custom_monitor(&"epiphany/enemies_alive") if Performance.has_custom_monitor(&"epiphany/enemies_alive") else 0,
		"OK" if p95 <= BUDGET_MS else "FUERA DE PRESUPUESTO"])


func _avg(values: Array) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxf(values.size(), 1)
