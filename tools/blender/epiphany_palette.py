bl_info = {
	"name": "Epiphany: paleta",
	"author": "Project Epiphany",
	"version": (1, 0, 0),
	"blender": (4, 2, 0),
	"location": "Vista 3D > N > Epiphany",
	"description": "Pinta caras con una franja de assets/epiphany/palette.png poniendo sus UV",
	"category": "UV",
}

import os

import bmesh
import bpy

# (nombre, arriba, abajo). El orden es el de la textura: 8 columnas, de izquierda a derecha y de arriba abajo.
SWATCHES = [
	("pasto", "a6c98a", "5e8a52"),
	("follaje", "86b46c", "3c6644"),
	("tierra", "cfae84", "8a6a4a"),
	("acantilado", "baa084", "6c5844"),
	("roca_naranja", "e39e5e", "9e5530"),
	("piedra", "b8b6ae", "6c6b67"),
	("piedra_templo", "aaa4be", "585370"),
	("musgo", "93b46c", "4c6a3a"),
	("madera", "d6a46c", "8c5c34"),
	("madera_oscura", "8c5c3c", "48301f"),
	("hierro", "959ba4", "3a3e46"),
	("dorado", "f5d67e", "b07a24"),
	("cristal", "d2f4ff", "56b0dc"),
	("sello", "b88ee2", "583088"),
	("doom", "ea725c", "86281f"),
	("ladrillo", "9298a0", "4e535b"),
	("hueso", "f4ecd8", "b6a688"),
	("piel", "f4caa2", "c08660"),
	("tela_roja", "d65a42", "7a2a20"),
	("tela_azul", "6292d6", "2a4a7c"),
	("agua", "8ed4e4", "2a6a8c"),
	("flor_amarilla", "ffe47e", "e0a030"),
	("flor_rosa", "f6a6bc", "be587a"),
	("fuego", "fff0b0", "ff8a3a"),
	("blanco", "ffffff", "d8d8d4"),
	("paja", "f0d890", "b08a40"),
	("gris_2", "a8a8a4", "7c7c78"),
	("cobre_verde", "8fd0b0", "3a7a6a"),
	("gris_4", "5a5a58", "363634"),
	("gris_5", "383836", "1c1c1c"),
	("noche", "202430", "0b0d10"),
	("neon", "b8fdff", "18b8d8"),
]
COLS, ROWS = 8, 4
# Franjas que brillan solas (palette_emission.png).
EMISSIVE = {"neon", "doom"}
# Fracción de la franja que no se usa arriba y abajo, para que el filtrado no mezcle con la vecina.
MARGIN = 0.06
MATERIAL = "paleta"
PALETTE_REL = os.path.join("assets", "epiphany", "palette.png")

_previews = None


def rgb(hex_color):
	return tuple(int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def palette_path():
	return os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__)))), PALETTE_REL)


def palette_material():
	mat = bpy.data.materials.get(MATERIAL)
	if mat:
		return mat
	mat = bpy.data.materials.new(MATERIAL)
	mat.use_nodes = True
	tree = mat.node_tree
	bsdf = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
	bsdf.inputs["Roughness"].default_value = 1.0
	tex = tree.nodes.new("ShaderNodeTexImage")
	tex.location = (bsdf.location.x - 320, bsdf.location.y)
	path = palette_path()
	image = next((i for i in bpy.data.images if os.path.realpath(bpy.path.abspath(i.filepath)) == os.path.realpath(path)), None)
	tex.image = image or bpy.data.images.load(path)
	tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	glow_path = os.path.join(os.path.dirname(path), "palette_emission.png")
	if os.path.exists(glow_path):
		glow = tree.nodes.new("ShaderNodeTexImage")
		glow.location = (bsdf.location.x - 320, bsdf.location.y - 300)
		glow.image = bpy.data.images.load(glow_path, check_existing=True)
		tree.links.new(glow.outputs["Color"], bsdf.inputs["Emission Color"])
		bsdf.inputs["Emission Strength"].default_value = 2.0
	return mat


class EPIPHANY_OT_swatch(bpy.types.Operator):
	"""Pone las caras seleccionadas (o todo el objeto, fuera de Edit Mode) en esta franja de la paleta"""
	bl_idname = "epiphany.swatch"
	bl_label = "Franja de la paleta"
	bl_options = {"REGISTER", "UNDO"}

	index: bpy.props.IntProperty()

	@classmethod
	def poll(cls, context):
		return any(o.type == "MESH" for o in context.selected_objects) or (context.object and context.object.type == "MESH")

	def execute(self, context):
		col, row = self.index % COLS, self.index // COLS
		u = (col + 0.5) / COLS
		v_low = (ROWS - 1 - row + MARGIN) / ROWS
		v_high = (ROWS - row - MARGIN) / ROWS
		shade = context.scene.epiphany_shade
		mat = palette_material()
		edit = context.mode == "EDIT_MESH"
		objects = [o for o in (context.objects_in_mode if edit else context.selected_objects) if o.type == "MESH"]
		for obj in objects:
			if mat.name not in obj.data.materials:
				obj.data.materials.append(mat)
			slot = list(obj.data.materials).index(bpy.data.materials[mat.name])
			if edit:
				bm = bmesh.from_edit_mesh(obj.data)
			else:
				bm = bmesh.new()
				bm.from_mesh(obj.data)
			uv = bm.loops.layers.uv.verify()
			faces = [f for f in bm.faces if f.select] if edit else list(bm.faces)
			heights = [(obj.matrix_world @ v.co).z for f in faces for v in f.verts]
			if not heights:
				continue
			z_min, z_max = min(heights), max(heights)
			for f in faces:
				f.material_index = slot
				for loop in f.loops:
					if shade == "GRADIENT":
						t = 0.5 if z_max - z_min < 1e-5 else ((obj.matrix_world @ loop.vert.co).z - z_min) / (z_max - z_min)
					else:
						t = {"LIGHT": 0.85, "MID": 0.5, "DARK": 0.15}[shade]
					loop[uv].uv = (u, v_low + (v_high - v_low) * t)
			if edit:
				bmesh.update_edit_mesh(obj.data)
			else:
				bm.to_mesh(obj.data)
				bm.free()
		return {"FINISHED"}


class EPIPHANY_PT_palette(bpy.types.Panel):
	bl_label = "Paleta"
	bl_space_type = "VIEW_3D"
	bl_region_type = "UI"
	bl_category = "Epiphany"

	def draw(self, context):
		layout = self.layout
		layout.prop(context.scene, "epiphany_shade", text="")
		grid = layout.grid_flow(row_major=True, columns=2, even_columns=True, align=True)
		for i, (name, _top, _bottom) in enumerate(SWATCHES):
			grid.operator(EPIPHANY_OT_swatch.bl_idname, text=name, icon_value=_previews[name].icon_id).index = i


def _build_previews():
	global _previews
	_previews = bpy.utils.previews.new()
	size = 16
	for name, top, bottom in SWATCHES:
		a, b = rgb(top), rgb(bottom)
		px = []
		for y in range(size):
			t = y / (size - 1)
			px += [b[k] + (a[k] - b[k]) * t for k in range(3)] + [1.0]
		preview = _previews.new(name)
		preview.icon_size = (size, size)
		preview.icon_pixels_float = [c for y in range(size) for _x in range(size) for c in px[y * 4:y * 4 + 4]]


def register():
	import bpy.utils.previews  # noqa: F401
	_build_previews()
	bpy.types.Scene.epiphany_shade = bpy.props.EnumProperty(
		name="Sombreado",
		items=[
			("GRADIENT", "Degradé por altura", "Claro arriba, oscuro abajo, según la altura de las caras"),
			("LIGHT", "Claro", ""),
			("MID", "Medio", ""),
			("DARK", "Oscuro", ""),
		],
	)
	bpy.utils.register_class(EPIPHANY_OT_swatch)
	bpy.utils.register_class(EPIPHANY_PT_palette)


def unregister():
	bpy.utils.unregister_class(EPIPHANY_PT_palette)
	bpy.utils.unregister_class(EPIPHANY_OT_swatch)
	del bpy.types.Scene.epiphany_shade
	bpy.utils.previews.remove(_previews)
