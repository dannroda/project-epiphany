extends Node
## Mide la compilación de pipelines (Performance PIPELINE_COMPILATIONS_*): entra al overworld con --scenario=start y
## larga cada efecto una vez al lado del player, con el peor frame y lo que compiló. Se carga como autoload desde un
## override.cfg temporal (ver tools/claude_windows/README.md).
const EFFECTS := [
	"res://src/feel/bursts/dust.tscn", "res://src/feel/bursts/explosion.tscn", "res://src/feel/bursts/leaves.tscn",
	"res://src/feel/bursts/shards.tscn", "res://src/feel/bursts/sparkle.tscn", "res://src/feel/bursts/sparks_gold.tscn",
	"res://src/feel/bursts/sparks.tscn", "res://src/feel/bursts/splash.tscn", "res://src/feel/bursts/wade.tscn",
	"res://src/items/bomb/explosion.tscn", "res://src/items/hammer/hammer_strike.tscn", "res://src/feel/shockwave.tscn",
	"res://src/feel/teleport.tscn", "res://src/feel/roar_ring.tscn", "res://src/feel/blessing.tscn", "res://src/feel/afterimage.tscn",
	"res://src/entities/boss/slam_crack.tscn", "res://src/entities/projectile.tscn",
]
const STEPS := ["CANVAS", "MESH", "SURFACE", "DRAW", "SPECIALIZATION"]
var _last := 0
var _worst := 0
func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_run()
func _process(_d: float) -> void:
	var now := Time.get_ticks_usec()
	if _last:
		_worst = maxi(_worst, now - _last)
	_last = now
func _counts() -> Dictionary:
	var d := {}
	for s in STEPS:
		d[s] = int(Performance.get_monitor(Performance.get("PIPELINE_COMPILATIONS_" + s)))
	return d
func _diff(a: Dictionary, b: Dictionary) -> String:
	var parts := []
	for s in STEPS:
		if b[s] != a[s]:
			parts.append("%s+%d" % [s.to_lower(), b[s] - a[s]])
	return ", ".join(parts) if parts else "-"
func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
func _run() -> void:
	var player: Node3D
	while true:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		player = get_tree().get_first_node_in_group(&"player")
		if scene and scene.scene_file_path.ends_with("overworld.tscn") and player and not get_tree().paused:
			break
	print("PROBE overworld up at %d ms since start (%s)  %s" % [Time.get_ticks_msec(), RenderingServer.get_current_rendering_driver_name(), _counts()])
	await _frames(120)
	_worst = 0
	await _frames(60)
	print("PROBE idle worst frame %5.1f ms  %s" % [_worst / 1000.0, _counts()])
	for path: String in EFFECTS:
		var before := _counts()
		_worst = 0
		var fx := (load(path) as PackedScene).instantiate()
		get_tree().current_scene.add_child(fx)
		if fx is Node3D:
			fx.global_position = player.global_position + Vector3(1.5, 1.0, 1.0)
		for p in fx.find_children("*", "GPUParticles3D", true, false) + ([fx] if fx is GPUParticles3D else []):
			p.emitting = true
		await _frames(40)
		print("PROBE %-22s worst frame %5.1f ms  %s" % [path.get_file(), _worst / 1000.0, _diff(before, _counts())])
	get_tree().quit()
