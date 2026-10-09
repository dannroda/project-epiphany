extends SceneTree
## Guarda cada pieza de los .blend de assets/epiphany como assets/epiphany/meshes/<blend>/<pieza>.res,
## con el material de la paleta compartido, para usarlas sueltas en escenas.
## godot --headless --path . --script res://tools/extract_epiphany_meshes.gd

const BLENDS := ["objetos", "equipo", "lugares", "templo", "naturaleza", "jefe"]
const DIR := "res://assets/epiphany/meshes/%s/"
const MATERIAL := preload("res://data/kits/materials/epiphany.tres")


func _initialize() -> void:
	var count := 0
	for blend: String in BLENDS:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR % blend))
		var scene: Node = (load("res://assets/epiphany/%s.blend" % blend) as PackedScene).instantiate()
		for node: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			var mesh := node.mesh.duplicate() as ArrayMesh
			for surface in mesh.get_surface_count():
				mesh.surface_set_material(surface, MATERIAL)
			mesh.resource_name = node.name
			var err := ResourceSaver.save(mesh, (DIR % blend) + node.name + ".res")
			if err != OK:
				push_error("%s/%s: %s" % [blend, node.name, error_string(err)])
			count += 1
		scene.free()
	print("extract_epiphany_meshes: ", count, " mallas")
	quit()
