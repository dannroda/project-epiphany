extends SceneTree
## Capturas del overworld y el templo con el material de paleta de siempre y con el toon (src/shaders/toon), en el
## jugador y en cada Spawn*: <nivel>_<lugar>_base.png y _toon.png. Necesita ventana (no headless).
## godot --path . --script res://tools/toon_preview.gd --resolution 960x540 -- <carpeta>
const TOON := preload("res://src/shaders/toon/epiphany_toon.tres")
var levels := ["res://levels/overworld.tscn", "res://levels/templo.tscn"]
var level: Node
var player: Node3D
var spots: Array = []
var li := -1
var si := 0
var pass_toon := false
var wait := 0

func _initialize() -> void:
	_next_level()

func _next_level() -> void:
	li += 1
	if level:
		level.queue_free()
	if li >= levels.size():
		return
	level = (load(levels[li]) as PackedScene).instantiate()
	get_root().add_child(level)
	player = level.get_node("Player")
	spots = [player.position]
	for m: Node in level.find_children("Spawn*", "Marker3D", false, false):
		spots.append((m as Node3D).position)
	spots = spots.slice(0, 5)
	si = 0
	pass_toon = false
	_place()

func _place() -> void:
	player.position = spots[si]
	wait = 45

func _process(_d: float) -> bool:
	if li >= levels.size():
		return true
	wait -= 1
	if wait > 0:
		return false
	var tag := "%d_%d_%s" % [li, si, "toon" if pass_toon else "base"]
	get_root().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join(tag + ".png"))
	if not pass_toon:
		_toonify(level)
		pass_toon = true
		wait = 8
		return false
	_restore(level)
	pass_toon = false
	si += 1
	if si >= spots.size():
		_next_level()
	else:
		_place()
	return false

var _saved := {}

func _toonify(root: Node) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var t := _toon_for(mi.get_active_material(s))
			if t:
				_saved[[mi, s]] = mi.get_surface_override_material(s)
				mi.set_surface_override_material(s, t)
	for gm: GridMap in root.find_children("*", "GridMap", true, false):
		var lib := gm.mesh_library
		for id in lib.get_item_list():
			var mesh := lib.get_item_mesh(id)
			if mesh == null:
				continue
			for s in mesh.get_surface_count():
				var t := _toon_for(mesh.surface_get_material(s))
				if t:
					_saved[[mesh, s]] = mesh.surface_get_material(s)
					mesh.surface_set_material(s, t)

func _restore(_root: Node) -> void:
	for k in _saved:
		if k[0] is MeshInstance3D:
			k[0].set_surface_override_material(k[1], _saved[k])
		else:
			k[0].surface_set_material(k[1], _saved[k])
	_saved.clear()

func _toon_for(m: Material) -> Material:
	if m is StandardMaterial3D and m.albedo_texture and m.albedo_texture.resource_path.ends_with("epiphany/palette.png"):
		return TOON
	if m is ShaderMaterial:
		var tex = m.get_shader_parameter("albedo_texture")
		if tex is Texture2D and tex.resource_path.ends_with("epiphany/palette.png") and m.get_shader_parameter("use_uv") != false:
			return TOON
	return null
