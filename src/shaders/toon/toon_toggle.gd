# Nodo de test_shinobi, solo en debug: debug_toon (tecla 4) cambia en runtime el material de paleta por el toon en todo lo cargado
# y en lo que se cargue después, sin tocar los .tres. Para probar el cel shading jugando (12.13).
extends Node

const ACTION := &"debug_toon"
const TOON := preload("res://src/shaders/toon/epiphany_toon.tres")
const PALETTE := "epiphany/palette.png"

var _on := false
## [MeshInstance3D o Mesh, superficie] → el material que tenía.
var _saved := {}
## Al llegar a este tamaño se olvidan las mallas liberadas (enemigos, ítems que van y vienen).
var _prune_at := 64


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		set_process_unhandled_input(false)
		return
	get_tree().node_added.connect(_on_node_added)


func _unhandled_input(event: InputEvent) -> void:
	if not (InputMap.has_action(ACTION) and event.is_action_pressed(ACTION)):
		return
	get_viewport().set_input_as_handled()
	set_enabled(not _on)


func set_enabled(on: bool) -> void:
	if on == _on or not OS.is_debug_build():
		return
	_on = on
	if _on:
		_apply_node(get_tree().root)
		for node in get_tree().root.find_children("*", "", true, false):
			_apply_node(node)
	else:
		_restore()
	var overlay := get_node_or_null(^"/root/DebugOverlay")
	if overlay:
		overlay.watch("toon", _on)
	var log := get_node_or_null(^"/root/Log")
	if log:
		log.info(&"toon", "cel shading " + ("on" if _on else "off"))


func _on_node_added(node: Node) -> void:
	if _on and (node is MeshInstance3D or node is GridMap):
		_apply_node.call_deferred(node)
		if _saved.size() >= _prune_at:
			for key: Array in _saved.keys():
				if not is_instance_valid(key[0]):
					_saved.erase(key)
			_prune_at = maxi(64, _saved.size() * 2)


func _apply_node(node: Variant) -> void:
	if not is_instance_valid(node):
		return
	if node is MeshInstance3D and node.mesh:
		for s in node.mesh.get_surface_count():
			var key := [node, s]
			if not _saved.has(key) and _is_palette(node.get_active_material(s)):
				_saved[key] = node.get_surface_override_material(s)
				node.set_surface_override_material(s, TOON)
	elif node is GridMap and node.mesh_library:
		for id in node.mesh_library.get_item_list():
			var mesh: Mesh = node.mesh_library.get_item_mesh(id)
			if mesh == null:
				continue
			for s in mesh.get_surface_count():
				var key := [mesh, s]
				if not _saved.has(key) and _is_palette(mesh.surface_get_material(s)):
					_saved[key] = mesh.surface_get_material(s)
					mesh.surface_set_material(s, TOON)


func _restore() -> void:
	for key: Array in _saved:
		if not is_instance_valid(key[0]):
			continue
		if key[0] is MeshInstance3D:
			key[0].set_surface_override_material(key[1], _saved[key])
		else:
			key[0].surface_set_material(key[1], _saved[key])
	_saved.clear()


func _is_palette(material: Material) -> bool:
	if material is StandardMaterial3D:
		return material.albedo_texture != null and material.albedo_texture.resource_path.ends_with(PALETTE)
	if material is ShaderMaterial and material != TOON:
		var tex: Variant = material.get_shader_parameter(&"albedo_texture")
		return tex is Texture2D and tex.resource_path.ends_with(PALETTE) and material.get_shader_parameter(&"use_uv") != false
	return false
