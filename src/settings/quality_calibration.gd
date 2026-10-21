class_name QualityCalibration
extends RefCounted
## La primera vez que arranca el juego (15.19): con el perfil de la plataforma mide la GPU del fondo del título a resolución
## completa y, si el cuadro tarda demasiado, baja un escalón. Lo guarda en Settings y no vuelve a decidir.

const WARMUP_MS := 500
const MEASURE_MS := 2000
## Cuadros por segundo que tiene que sostener el perfil: 60 en PC, 30 en Mobile.
const TARGET_FPS := 60.0
const TARGET_FPS_MOBILE := 30.0
## Margen sobre el cuadro del objetivo antes de bajar.
const SLACK := 1.2


## `flyover`: el contenedor del fondo del título, con su SubViewport ya mostrando el overworld.
static func run(flyover: SubViewportContainer) -> void:
	var id := Settings.platform_profile()
	Settings.apply_profile(id, false)
	var viewport: SubViewport = flyover.get_child(0)
	var shrink := flyover.stretch_shrink
	flyover.stretch_shrink = 1
	var scale: int = Settings.get_value(&"render_scale")
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 100 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = scale / 100.0
	var rid := viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var tree := flyover.get_tree()
	var start := Time.get_ticks_msec()
	var samples: Array[float] = []
	while Time.get_ticks_msec() - start < WARMUP_MS + MEASURE_MS:
		await tree.process_frame
		if Time.get_ticks_msec() - start >= WARMUP_MS:
			samples.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	RenderingServer.viewport_set_measure_render_time(rid, false)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = 1.0
	flyover.stretch_shrink = shrink
	var gpu := median(samples)
	var target := TARGET_FPS_MOBILE if RenderingServer.get_current_rendering_method() == "mobile" else TARGET_FPS
	var chosen := decide(id, gpu, target)
	Log.info(&"settings", "Perfil de calidad", chosen, "GPU %.1f ms" % gpu)
	Settings.apply_profile(chosen)


## Un escalón abajo de `id` si la GPU pasa del cuadro de `target` fps con el margen.
static func decide(id: String, gpu_ms: float, target: float) -> String:
	var at := Settings.PROFILE_ORDER.find(id)
	return Settings.PROFILE_ORDER[maxi(at - 1, 0)] if gpu_ms > SLACK * 1000.0 / target else id


static func median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]
