extends Node
## Benchmark automático (15.14). Quieto salvo que el juego arranque con `--benchmark` o el feature "benchmark": entonces
## corre cada BenchCase (hijos de Cases) en cada BenchVariant (hijos de Variants) sin input, anota cuadro a cuadro, deja
## una línea BENCH por corrida y todo junto en user://benchmark/latest.json, y cierra el juego.
## PC: tools/bench.sh desktop · Android: tools/bench.sh android <serial>.

const ARG := "--benchmark"
const OUT := "user://benchmark/latest.json"

## Segundos caminando antes de empezar a anotar, para que asienten la carga y los shaders.
@export var warmup := 2.0

var _flat := StandardMaterial3D.new()
var _variant: BenchVariant


func _ready() -> void:
	if ARG in OS.get_cmdline_args() or ARG in OS.get_cmdline_user_args() or OS.has_feature("benchmark"):
		_run.call_deferred()
	else:
		for marker: Node in [$FrameStart, $FrameEnd]:
			marker.process_mode = PROCESS_MODE_DISABLED


func _run() -> void:
	await get_tree().process_frame
	var viewport := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	Settings.set_value(&"max_fps", 0, false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var info := {
		"device": OS.get_model_name(), "os": OS.get_name(), "gpu": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "screen": get_viewport().get_visible_rect().size,
		"debug": OS.is_debug_build(), "date": Time.get_datetime_string_from_system(),
		"vsync": DisplayServer.window_get_vsync_mode(),
	}
	print("BENCH_INFO ", JSON.stringify(info))
	var runs := []
	for variant: BenchVariant in $Variants.get_children():
		for bench: BenchCase in $Cases.get_children():
			if not variant.cases.is_empty() and bench.name not in variant.cases:
				continue
			var run := await _measure(bench, variant, viewport)
			print("BENCH ", JSON.stringify(run))
			runs.append(run)
			_save(info, runs)
	print("BENCH_DONE ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


## Después de cada corrida: si el teléfono pierde el dispositivo a mitad de camino, quedan las que terminaron.
func _save(info: Dictionary, runs: Array) -> void:
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"info": info, "runs": runs}, "\t"))
	file.close()


func _measure(bench: BenchCase, variant: BenchVariant, viewport: RID) -> Dictionary:
	var run := {"case": bench.name, "variant": variant.name}
	Settings.set_value(&"render_scale", variant.render_scale, false)
	Settings.set_value(&"shadows", variant.shadows, false)
	Settings.set_value(&"ssao", variant.ssao, false)
	var loaded_at := Time.get_ticks_msec()
	var err: Error = await SaveManager.load_scenario(bench.scenario)
	while SceneFlow.is_busy():
		await get_tree().process_frame
	run["load_ms"] = Time.get_ticks_msec() - loaded_at
	var player := Players.lead()
	if err != OK or player == null:
		run["error"] = error_string(err) if err != OK else "no player"
		return run
	_strip(get_tree().current_scene, variant)
	_variant = variant
	if variant.flat_materials:
		_flatten(get_tree().current_scene)
		get_tree().node_added.connect(_flatten)
	var restore := _apply(variant, get_tree().current_scene)
	var lod_threshold := get_viewport().mesh_lod_threshold
	if not variant.lods:
		get_viewport().mesh_lod_threshold = 0.0
	player.health.make_invulnerable(3600.0)
	var origin := player.global_position if bench.use_spawn else bench.center
	var columns := {"frame": [], "process": [], "physics": [], "scripts": [], "physics_scripts": [], "physics_steps": [], "physics_engine": [], "navigation": [], "render_cpu": [], "render_gpu": [], "draws": [], "triangles": [], "objects": []}
	var elapsed := -warmup
	var last := Time.get_ticks_usec()
	while elapsed < bench.seconds:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var delta := (now - last) / 1000000.0
		last = now
		elapsed += delta
		_walk(player, origin, bench, elapsed)
		var scripts: Array = $FrameEnd.take()
		if elapsed < 0.0:
			continue
		columns.scripts.append(scripts[0])
		columns.physics_scripts.append(scripts[1])
		columns.physics_steps.append(scripts[2])
		if scripts[4] > 0:
			columns.physics_engine.append(scripts[3] / scripts[4])
		columns.navigation.append(Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0)
		columns.frame.append(delta * 1000.0)
		columns.process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		columns.physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		columns.render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport) + RenderingServer.get_frame_setup_time_cpu())
		columns.render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		columns.draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		columns.triangles.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		columns.objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	if get_tree().node_added.is_connected(_flatten):
		get_tree().node_added.disconnect(_flatten)
	restore.call()
	get_viewport().mesh_lod_threshold = lod_threshold
	var frames: Array = columns.frame
	run["fps"] = 1000.0 * frames.size() / maxf(_sum(frames), 0.001)
	for key: String in columns:
		run[key] = _summary(columns[key])
	run["nodes"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	run["video_mb"] = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	run["static_mb"] = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	return run


## En círculo alrededor de `origin`, apoyado en el piso que haya debajo.
func _walk(player: PlayerCharacter, origin: Vector3, bench: BenchCase, elapsed: float) -> void:
	var angle := maxf(elapsed, 0.0) * bench.speed / maxf(bench.radius, 0.1)
	var spot := origin + Vector3(cos(angle), 0.0, sin(angle)) * bench.radius
	var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 20.0, spot + Vector3.DOWN * 20.0, player.collision_mask, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	player.global_position = hit.position if hit else spot
	player.velocity = Vector3.ZERO


func _strip(scene: Node, variant: BenchVariant) -> void:
	for light: Light3D in scene.find_children("*", "Light3D", true, false):
		if not light is DirectionalLight3D and not variant.lights:
			light.visible = false
	for probe: ReflectionProbe in scene.find_children("*", "ReflectionProbe", true, false):
		if not variant.probes:
			probe.visible = false
	if not variant.effects:
		for world: WorldEnvironment in scene.find_children("*", "WorldEnvironment", true, false):
			world.compositor = null
		var camera := get_viewport().get_camera_3d()
		if camera:
			camera.compositor = null
	if not variant.dof:
		for world: WorldEnvironment in scene.find_children("*", "WorldEnvironment", true, false):
			world.camera_attributes = null
		var camera := get_viewport().get_camera_3d()
		if camera:
			camera.attributes = null
	for grid: GridMap in scene.find_children("*", "GridMap", true, false):
		if not variant.gridmaps:
			grid.visible = false


func _flatten(node: Node) -> void:
	for geometry: GeometryInstance3D in node.find_children("*", "GeometryInstance3D", true, false) + ([node] if node is GeometryInstance3D else []):
		if _flattens(_materials(geometry)):
			geometry.material_override = _flat
	for grid: GridMap in node.find_children("*", "GridMap", true, false) + ([node] if node is GridMap else []):
		if grid.mesh_library == null:
			continue
		var library: MeshLibrary = grid.mesh_library.duplicate()
		for item in library.get_item_list():
			var mesh := library.get_item_mesh(item)
			if mesh == null or not _flattens(_mesh_materials(mesh)):
				continue
			mesh = mesh.duplicate()
			for surface in mesh.get_surface_count():
				mesh.surface_set_material(surface, _flat)
			library.set_item_mesh(item, mesh)
		grid.mesh_library = library


func _flattens(materials: Array) -> bool:
	if _variant.flat_shaders.is_empty():
		return true
	var hit := materials.any(func(m: Material) -> bool: return m is ShaderMaterial and m.shader in _variant.flat_shaders)
	return hit != _variant.flat_except


func _materials(geometry: GeometryInstance3D) -> Array:
	var out := [geometry.material_override] if geometry.material_override else []
	var mesh: Mesh = geometry.get(&"mesh") if geometry is MeshInstance3D else null
	if geometry is MultiMeshInstance3D and geometry.multimesh:
		mesh = geometry.multimesh.mesh
	if mesh:
		for surface in mesh.get_surface_count():
			var m: Material = geometry.get_surface_override_material(surface) if geometry is MeshInstance3D else null
			if m == null:
				m = mesh.surface_get_material(surface)
			if m:
				out.append(m)
	return out


func _mesh_materials(mesh: Mesh) -> Array:
	var out := []
	for surface in mesh.get_surface_count():
		if mesh.surface_get_material(surface):
			out.append(mesh.surface_get_material(surface))
	return out


## Los parámetros de shader, los efectos apagados y las sombras de plantas de la variante; devuelve cómo dejar los recursos
## compartidos como estaban.
func _apply(variant: BenchVariant, scene: Node) -> Callable:
	var undo := []
	if variant.parameters_shader and (not variant.parameters.is_empty() or variant.swap_shader):
		var seen := {}
		var found := []
		for geometry: GeometryInstance3D in scene.find_children("*", "GeometryInstance3D", true, false):
			found.append_array(_materials(geometry))
		for grid: GridMap in scene.find_children("*", "GridMap", true, false):
			for item in grid.mesh_library.get_item_list() if grid.mesh_library else []:
				if grid.mesh_library.get_item_mesh(item):
					found.append_array(_mesh_materials(grid.mesh_library.get_item_mesh(item)))
		for m: Material in found:
			if m is ShaderMaterial and m.shader == variant.parameters_shader and not seen.has(m):
				seen[m] = true
				if variant.swap_shader:
					undo.append([m, &"shader", m.shader])
					m.shader = variant.swap_shader
				for key: String in variant.parameters:
					undo.append([m, key, m.get_shader_parameter(key)])
					m.set_shader_parameter(key, variant.parameters[key])
	var effects := []
	for world: WorldEnvironment in scene.find_children("*", "WorldEnvironment", true, false):
		for effect in world.compositor.compositor_effects if world.compositor else []:
			if effect and effect.enabled and effect.get_script() in variant.effects_off:
				effect.enabled = false
				effects.append(effect)
	for sun: DirectionalLight3D in scene.find_children("*", "DirectionalLight3D", true, false):
		if variant.sun_orthogonal:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		if variant.sun_distance > 0.0:
			sun.directional_shadow_max_distance = variant.sun_distance
	if variant.shadow_atlas > 0:
		RenderingServer.directional_shadow_atlas_set_size(variant.shadow_atlas, ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits"))
	if variant.monitoring_off:
		for area: Area3D in scene.find_children("*", "Area3D", true, false):
			area.set_deferred(&"monitoring", false)
	if variant.enemies_off:
		for enemy in get_tree().get_nodes_in_group(Enemy.GROUP):
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
	if variant.dof_quality >= 0:
		RenderingServer.camera_attributes_set_dof_blur_quality(variant.dof_quality, ProjectSettings.get_setting("rendering/camera/depth_of_field/depth_of_field_use_jitter"))
	if variant.dof_shape >= 0:
		RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(variant.dof_shape)
	if not variant.plant_shadows:
		for node in scene.find_children("*", "", true, false):
			if node.scene_file_path.begins_with("res://src/world/plants/") or node.name == &"Decor":
				for geometry: GeometryInstance3D in node.find_children("*", "GeometryInstance3D", true, false):
					geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return func() -> void:
		RenderingServer.camera_attributes_set_dof_blur_quality(ProjectSettings.get_setting("rendering/camera/depth_of_field/depth_of_field_bokeh_quality"), ProjectSettings.get_setting("rendering/camera/depth_of_field/depth_of_field_use_jitter"))
		RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(ProjectSettings.get_setting("rendering/camera/depth_of_field/depth_of_field_bokeh_shape"))
		for effect: CompositorEffect in effects:
			effect.enabled = true
		for entry: Array in undo:
			if entry[1] == &"shader":
				entry[0].shader = entry[2]
			else:
				entry[0].set_shader_parameter(entry[1], entry[2])


func _summary(values: Array) -> Dictionary:
	if values.is_empty():
		return {}
	var sorted := values.duplicate()
	sorted.sort()
	return {"avg": _sum(values) / values.size(), "p50": sorted[sorted.size() / 2], "p95": sorted[int(sorted.size() * 0.95)], "max": sorted.back()}


func _sum(values: Array) -> float:
	var total := 0.0
	for value: float in values:
		total += value
	return total
