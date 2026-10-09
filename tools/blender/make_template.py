# Arma tools/blender/plantilla.blend: material de la paleta, el Knight y las alturas del kit para medir.
# blender -b -P tools/blender/make_template.py
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import epiphany_palette  # noqa: E402

# (nombre, altura de arriba). Todas bajan hasta -0.5, como las celdas del kit gris.
HEIGHTS = [("ref_piso", 0.0), ("ref_escalon", 0.6), ("ref_cerco", 0.9), ("ref_pared", 2.6)]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0

refs = bpy.data.collections.new("referencias")
scene.collection.children.link(refs)
refs.hide_render = True


def ref_object(obj):
	for c in obj.users_collection:
		c.objects.unlink(obj)
	refs.objects.link(obj)
	obj.hide_select = True
	obj.hide_render = True


for i, (name, top) in enumerate(HEIGHTS):
	bpy.ops.mesh.primitive_cube_add(size=1.0)
	box = bpy.context.object
	box.name = name
	box.scale = (2.0, 2.0, top + 0.5)
	box.location = (-6.0 + i * 2.5, 4.0, (top - 0.5) / 2.0)
	box.display_type = "WIRE"
	ref_object(box)

bpy.ops.mesh.primitive_grid_add(x_subdivisions=5, y_subdivisions=5, size=10.0)
grid = bpy.context.object
grid.name = "ref_grilla_2m"
grid.display_type = "WIRE"
ref_object(grid)

before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "kaykit_adventure", "Characters", "gltf", "Knight.glb"))
# El importador deja la forma de los huesos (una esfera) en glTF_not_exported.
helpers = bpy.data.collections.get("glTF_not_exported")
if helpers:
	for obj in list(helpers.objects):
		bpy.data.objects.remove(obj)
	bpy.data.collections.remove(helpers)
for obj in set(bpy.data.objects) - before:
	ref_object(obj)
	if obj.parent is None:
		obj.location = (3.0, 0.0, 0.0)
	if obj.type == "ARMATURE":
		for bone in obj.pose.bones:
			bone.custom_shape = None
		obj.hide_set(True)
# Que use el PNG del pack en vez de una copia empaquetada: si no, Godot la desempaqueta al importar.
for image in bpy.data.images:
	if image.packed_file and image.name.startswith("knight"):
		image.unpack(method="REMOVE")
		image.filepath = os.path.join(ROOT, "assets", "kaykit_adventure", "Characters", "gltf", "knight_texture.png")

epiphany_palette.palette_material().use_fake_user = True
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "plantilla.blend"))
bpy.ops.file.make_paths_relative()
bpy.ops.wm.save_mainfile()
knight = [o for o in refs.objects if o.type == "MESH"]
print("knight top:", max((o.matrix_world @ v.co).z for o in knight for v in o.data.vertices))
