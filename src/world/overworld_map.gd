class_name OverworldMap
extends Node
## Va en las escenas del overworld: el mapa de la zona y qué rectángulo del mundo (XZ) cubre. La imagen es una foto
## cenital ortográfica de `scenery` que se saca al abrir el mapa, así siempre muestra el layout y los assets actuales.

signal photo_requested

## Capa de render que solo ve la cámara del mapa (player, enemigos y objetos quedan afuera de la foto).
const MAP_LAYER := 20
const PIXELS_PER_METER := 20.0
const CAMERA_HEIGHT := 60.0
## Una malla del suelo copiada para la foto (en la capa del mapa).
const MAP_PIECE := preload("res://src/world/map_piece.tscn")
## Después de un cambio persistente (un flag), la foto se vuelve a sacar cuando terminó de moverse (el puente sube en 1,4 s).
const RETAKE_DELAY := 2.0

@export var display_name: String = ""
@export var world_rect := Rect2(-20, -20, 40, 40)
## Sus paredes se recortan alrededor del player (player_hole), salvo en el borde del mundo: ahí el agujero
## mostraría el vacío, así que se cambian por su variante "borde" y queda la silueta.
@export var grid: GridMap
## Lo que sale en la foto del mapa (además de `grid`), con sus hijos.
@export var scenery: Array[Node3D] = []

var texture: Texture2D
var _retake_pending := false

@onready var _viewport: SubViewport = $Snapshot
@onready var _camera: Camera3D = $Snapshot/Camera
## Dónde va la copia del GridMap mientras se saca la foto.
@onready var _grid_copy_root: Node3D = %GridCopy


func _ready() -> void:
	if grid:
		use_edge_walls(grid)
	for node in scenery:
		_add_to_map_layer(node)
	_viewport.size = Vector2i((world_rect.size * PIXELS_PER_METER).round())
	var center := world_rect.get_center()
	_camera.position = Vector3(center.x, CAMERA_HEIGHT, center.y)
	_camera.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	_camera.size = world_rect.size.y
	_camera.far = CAMERA_HEIGHT * 2.0
	texture = _viewport.get_texture()
	GameState.flag_changed.connect(_on_flag_changed)


## Saca la foto en el próximo frame, sin el agujero del player (la cámara del juego está en pausa con el mapa abierto).
func snapshot() -> void:
	photo_requested.emit()
	var camera := get_viewport().get_camera_3d()
	var hole: Vector4 = camera.player_hole if camera is TopDownCamera else Vector4.ZERO
	RenderingServer.global_shader_parameter_set(&"player_hole", Vector4.ZERO)
	var copied := _grid_copy()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	RenderingServer.global_shader_parameter_set(&"player_hole", hole)
	if copied:
		for piece in _grid_copy_root.get_children():
			piece.queue_free()


func _on_flag_changed(_id: StringName, _value: Variant) -> void:
	if _retake_pending or not is_inside_tree():
		return
	_retake_pending = true
	await get_tree().create_timer(RETAKE_DELAY).timeout
	_retake_pending = false
	if is_inside_tree():
		snapshot()


static func _add_to_map_layer(node: Node) -> void:
	if node is VisualInstance3D:
		node.set_layer_mask_value(MAP_LAYER, true)
	for child in node.get_children():
		_add_to_map_layer(child)


## GridMap no tiene capas de render: para la foto se copian sus mallas (un MultiMesh por malla) solo en la capa del mapa.
## Las paredes "borde" vuelven a ser las normales: desde arriba no tienen tapa.
func _grid_copy() -> bool:
	if not grid or not grid.is_inside_tree():
		return false
	var library := grid.mesh_library
	var by_mesh: Dictionary[Mesh, Array] = {}
	for cell in grid.get_used_cells():
		var item := _without_edge(library, grid.get_cell_item(cell))
		var mesh := library.get_item_mesh(item)
		if mesh == null:
			continue
		var basis := grid.get_basis_with_orthogonal_index(grid.get_cell_item_orientation(cell)).scaled(Vector3.ONE * grid.cell_scale)
		by_mesh.get_or_add(mesh, []).append(Transform3D(basis, grid.map_to_local(cell)) * library.get_item_mesh_transform(item))
	for piece in _grid_copy_root.get_children():
		piece.free()
	_grid_copy_root.transform = grid.global_transform
	for mesh in by_mesh:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = by_mesh[mesh].size()
		for i in multimesh.instance_count:
			multimesh.set_instance_transform(i, by_mesh[mesh][i])
		var piece := MAP_PIECE.instantiate() as MultiMeshInstance3D
		piece.multimesh = multimesh
		_grid_copy_root.add_child(piece)
	return true


static func _without_edge(library: MeshLibrary, item: int) -> int:
	var item_name := library.get_item_name(item)
	if not item_name.ends_with(" borde"):
		return item
	var base := library.find_item_by_name(item_name.trim_suffix(" borde"))
	return base if base >= 0 else item


static func use_edge_walls(map: GridMap) -> void:
	var library := map.mesh_library
	var edge_of := {}
	for id in library.get_item_list():
		var edge := library.find_item_by_name(library.get_item_name(id) + " borde")
		if edge >= 0:
			edge_of[id] = edge
	edge_of[library.find_item_by_name("Acantilado")] = library.find_item_by_name("Andén borde")
	for cell in map.get_used_cells():
		var item := map.get_cell_item(cell)
		if edge_of.has(item) and edge_of[item] >= 0 and map.get_cell_item(cell + Vector3i(0, 0, 1)) == GridMap.INVALID_CELL_ITEM:
			map.set_cell_item(cell, edge_of[item], map.get_cell_item_orientation(cell))
