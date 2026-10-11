# Renderiza el ojo del jefe (solo el globo y los párpados, sin el cuerpo) para el ícono del juego: un PNG de 512 px con
# fondo transparente. Lo usa tools/build_icon.sh, que arma la placa y los tamaños.
# blender -b -P tools/blender/render_icon.py -- <salida.png>
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = sys.argv[sys.argv.index("--") + 1]
EYE = Vector((0.0, -1.38, 0.3))
LIDS = 0.55
PIECES = ("jefe_ojo", "jefe_parpado", "jefe_parpado_inf")

bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, "art", "blender", "jefe.blend"))
sc = bpy.context.scene
for obj in bpy.data.objects:
	obj.hide_render = obj.name not in PIECES
	obj.location = EYE
	obj.rotation_euler = (0, 0, 0)
bpy.data.objects["jefe_parpado"].rotation_euler = (-LIDS, 0, 0)
bpy.data.objects["jefe_parpado_inf"].rotation_euler = (LIDS, 0, 0)

sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x = sc.render.resolution_y = 512
sc.render.film_transparent = True
sc.view_settings.view_transform = "Standard"
sc.world = bpy.data.worlds.new("icono")
sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.55, 1)
sun = bpy.data.objects.new("sol", bpy.data.lights.new("sol", "SUN"))
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(55), 0, math.radians(-25))
sc.collection.objects.link(sun)
cam = bpy.data.objects.new("camara", bpy.data.cameras.new("camara"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 3.7
sc.collection.objects.link(cam)
sc.camera = cam
cam.location = EYE + Vector((0.0, -6.6, 0.3))
cam.rotation_euler = (EYE - cam.location).to_track_quat("-Z", "Y").to_euler()
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("icono:", OUT)
