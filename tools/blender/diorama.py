# Arma una escena chica con piezas de los kits y la renderiza con la cámara del juego (FOV 40, offset 0/17.4/10).
# blender -b -P tools/blender/diorama.py -- <salida.png> [escena] [kit que reemplaza al primero, p. ej. templo_chullpa]
# blender -b -P tools/blender/diorama.py -- <salida.png> vitrina <kit> [pieza,pieza,...]   (piezas del kit en grilla, encuadradas)
# Las escenas están en ESCENAS: cada celda es "pieza[@giro]" (giro en cuartos de vuelta), a 2 m; "+" apila un nivel (2.6 m).
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
LEVEL = 2.6

ESCENAS = {
	"overworld": {
		"kits": ["terreno_overworld", "naturaleza"],
		"target": (0.0, 0.0),
		"grid": [
			"anden anden anden anden escalinata anden anden anden anden",
			"pasto pasto_flores pasto lajas_pasto lajas lajas_rotas pasto_ichu pasto anden",
			"pasto pasto pasto_ichu tierra_borde@2 tierra tierra_borde pasto pasto anden",
			"pirca pirca pirca_final tierra_borde@2 tierra tierra_borde pasto pasto_piedras risco",
			"pasto pasto_piedras pasto tierra_borde@2 tierra tierra_borde pasto pasto risco",
			"pasto pasto pasto_flores tierra_borde@2 tierra tierra_borde pasto_flores pasto risco",
			"pasto pasto_ichu pasto tierra_borde@2 tierra tierra_borde pasto pasto pasto",
			"pasto pasto pasto tierra_borde@2 tierra tierra_borde pasto pirca_rota pasto",
		],
		"props": [
			("quenoa_grande", -7.0, 4.6, 0.0), ("quenoa_chica", -3.4, 3.8, 1.0), ("quenoa_grande", 6.2, -6.0, 2.0),
			("cardon_a", 4.6, 4.2, 0.3), ("cardon_b", 6.8, 1.6, 1.2), ("cardon_chico", -5.6, -2.5, 0.0),
			("ichu_mata", -2.6, -4.0, 0.0), ("ichu_mata", -6.0, -5.6, 1.0), ("ichu_mata", 2.8, -3.0, 2.0), ("ichu_cortado", -3.4, -5.4, 0.0),
			("tola", 3.0, 1.0, 0.0), ("tola", -7.4, 0.2, 1.0),
			("roca_grande_a", -1.0, -7.0, 0.0), ("roca_grande_b", 7.0, -2.0, 1.0), ("roca_alta", -7.8, -7.0, 0.0),
			("roca_fisica", 2.6, -6.2, 0.0), ("piedra_chica_a", 1.4, 3.2, 0.0), ("tronco_caido", -4.4, 0.6, 0.6),
		],
	},
	"templo": {
		"kits": ["templo", "lugares", "objetos"],
		"target": (0.0, 2.0),
		"grid": [
			"pared pared pared_nicho pared paso_puerta pared pared_nicho pared pared",
			"pared piso piso piso piso piso piso piso pared",
			"pared_ojo piso columna piso_musgo piso piso columna piso pared_ojo",
			"pared piso piso piso piso_grieta piso piso piso_roto pared",
			"paso_puerta piso piso piso piso piso piso piso pared",
			"pared piso columna piso piso_musgo piso columna piso pared",
			"pared piso piso piso piso piso piso piso pared",
			"pared pared pared pared paso_puerta pared pared pared pared",
		],
		"props": [
			("brasero", -5.0, 4.6, 0.0), ("brasero", 5.0, 4.6, 0.0),
			("bloque_empujable", -2.0, -2.0, 0.0), ("interruptor_marco", 4.0, -2.0, 0.0), ("interruptor_placa", 4.0, -2.0, 0.0),
			("cofre", 6.0, 2.0, 0.0), ("cofre_tapa", 6.0, 1.65, 0.0), ("vasija", -6.0, -4.4, 0.0), ("vasija", -5.3, -4.8, 0.0),
			("torreta", 0.0, 2.0, 0.0), ("tablilla", -6.0, 3.0, 0.0),
		],
	},
}


def main():
	argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	out = argv[0] if argv else os.path.join(HERE, "diorama.png")
	showcase = len(argv) > 2 and argv[1] == "vitrina"
	scene_def = {"kits": [argv[2]], "grid": [], "props": [], "target": (0.0, 0.0)} if showcase else dict(ESCENAS[argv[1] if len(argv) > 1 else "overworld"])
	if not showcase and len(argv) > 2:
		scene_def["kits"] = [argv[2]] + scene_def["kits"][1:]
	bpy.ops.wm.read_factory_settings(use_empty=True)
	sc = bpy.context.scene
	pieces = {}
	for kit in scene_def["kits"]:
		path = os.path.join(ROOT, "art", "blender", kit + ".blend")
		if not os.path.exists(path):
			continue
		with bpy.data.libraries.load(path) as (src, dst):
			dst.objects = [n for n in src.objects if not n.startswith(("ref_", "Knight", "Rig_"))]
		for obj in dst.objects:
			if obj is not None and obj.type == "MESH":
				pieces[obj.name] = obj
	rows = scene_def["grid"]
	depth = len(rows)
	for r, line in enumerate(rows):
		for c, cell in enumerate(line.split()):
			for k, token in enumerate(cell.split("+")):
				if token == ".":
					continue
				name, _, turn = token.partition("@")
				if name not in pieces:
					print("falta pieza:", name)
					continue
				inst = bpy.data.objects.new(name, pieces[name].data)
				x = (c - (len(line.split()) - 1) / 2) * 2.0
				y = ((depth - 1) / 2 - r) * 2.0
				inst.location = (x, y, k * LEVEL)
				inst.rotation_euler.z = int(turn or 0) * math.pi / 2
				sc.collection.objects.link(inst)
	for name, x, y, turn in scene_def["props"]:
		if name in pieces:
			inst = bpy.data.objects.new(name, pieces[name].data)
			inst.location = (x, y, 0)
			inst.rotation_euler.z = turn
			sc.collection.objects.link(inst)
	cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
	sc.collection.objects.link(cam)
	cam.data.angle = math.radians(40)
	cam.data.sensor_fit = "VERTICAL"
	if showcase:
		only = set(argv[3].split(",")) if len(argv) > 3 else None
		_showcase(sc, {k: v for k, v in pieces.items() if only is None or k in only}, cam)
	else:
		tx, ty = scene_def["target"]
		cam.location = (tx, ty - 10.0, 17.4)
		cam.rotation_euler = (Vector((tx, ty, 0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
	sc.camera = cam
	sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
	sc.collection.objects.link(sun)
	sun.data.energy = 3.2
	sun.data.color = (1.0, 0.96, 0.88)
	sun.data.angle = math.radians(3)
	sun.rotation_euler = (math.radians(45), math.radians(10), math.radians(35))
	world = bpy.data.worlds.new("w")
	world.use_nodes = True
	sc.world = world
	bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
	bg.inputs[0].default_value = (0.62, 0.66, 0.78, 1)
	bg.inputs[1].default_value = 0.9
	engines = [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
	sc.render.engine = next(e for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT") if e in engines)
	sc.render.resolution_x, sc.render.resolution_y = 1280, 720
	sc.view_settings.view_transform = "Standard"
	sc.render.filepath = out
	bpy.ops.render.render(write_still=True)
	print("diorama:", out)


def _showcase(sc, pieces, cam):
	"""Grilla con un hueco proporcional al tamaño de cada pieza, vista de tres cuartos desde adelante."""
	objs = sorted(pieces.values(), key=lambda o: o.name)
	cols = max(1, math.ceil(math.sqrt(len(objs) * 1.6)))
	sizes = [max(o.dimensions.x, o.dimensions.y, 0.4) for o in objs]
	cell = max(sizes) * 1.25
	for i, obj in enumerate(objs):
		inst = bpy.data.objects.new(obj.name, obj.data)
		inst.location = ((i % cols) * cell, -(i // cols) * cell, 0)
		sc.collection.objects.link(inst)
	rows = math.ceil(len(objs) / cols)
	center = Vector(((cols - 1) * cell / 2, -(rows - 1) * cell / 2, 0.3))
	span = max(cols, rows * 1.6) * cell
	cam.location = center + Vector((0, -0.75, 0.85)).normalized() * span * 1.25
	cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()


main()
