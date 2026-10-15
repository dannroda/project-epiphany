# Publica assets/epiphany/atoq.glb (epi.publish): el atoq, el zorro andino de la Cumbre (11.196). Piezas rígidas, cada
# una con el origen donde gira, que atoq_model.tscn cuelga de sus pivotes y anima: atoq_cuerpo (centro del cuerpo),
# atoq_cabeza (la nuca), atoq_mandibula (la bisagra), atoq_pata_del / atoq_pata_tras (hombro y cadera, hacia abajo) y
# atoq_cola (la base, hacia atrás). atoq_pelo_cuerpo (desde el centro del cuerpo) y atoq_pelo_cabeza (desde la nuca) son
# los mechones que se mueven con resortes, como la trenza del jugador: cada mechón es una cadena de huesos que
# tools/build_atoq_fur.gd lee de art/blender/atoq_pelo.json (la cola también es una cadena). El hocico mira a -Y (+Z en Godot, como los modelos de KayKit que usa Enemy). Pelaje gris con la cabeza y las patas rojizas, pecho y panza
# blancos, la punta de la cola negra.
# blender -b --factory-startup -P tools/blender/build_atoq.py
import json
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

kit = epi.start()

BACK = "gris_2"
RUST = "roca_naranja"
BELLY = "hueso"
DARK = "gris_5"


def piece(name, seed, fn, smooth=40):
	p = epi.Piece(seed)
	fn(p)
	return p.build(name, kit, smooth=smooth)


def cuerpo(p):
	"""Torso alargado con el lomo gris, la panza blanca y el cuello que sube hacia la nuca (0, -0.36, 0.2)."""
	torso = p.blob((0, 0, 0), 0.3, squash=(0.6, 1.35, 0.62), subdiv=2, rough=0.04)
	p.paint(torso, BACK, z_range=(-0.3, 0.3), vary=0.06)
	belly = p.blob((0, 0.02, -0.08), 0.26, squash=(0.52, 1.15, 0.45), subdiv=2, rough=0.03)
	p.paint(belly, BELLY, "MID", vary=0.04)
	neck = p.blob((0, -0.3, 0.12), 0.17, squash=(0.85, 1.0, 1.15), subdiv=2, rough=0.03)
	p.paint(neck, RUST, "MID", vary=0.05)
	chest = p.blob((0, -0.36, 0.02), 0.13, squash=(0.9, 0.7, 1.1), subdiv=2, rough=0.02)
	p.paint(chest, BELLY, "LIGHT")


def cabeza(p):
	"""Cráneo rojizo con el hocico largo hacia -Y, nariz negra, orejas grandes de punta oscura y ojos con brillo."""
	skull = p.blob((0, -0.08, 0.06), 0.15, squash=(1.0, 1.05, 0.9), subdiv=2, rough=0.03)
	p.paint(skull, RUST, "MID", vary=0.05)
	snout = p.cylinder(0.075, 0.0, 0.2, sides=8, radius_top=0.035)
	p.transform(snout, Matrix.Translation((0, -0.18, 0.04)) @ Matrix.Rotation(1.65, 4, "X"))
	p.paint(snout, RUST, "LIGHT", vary=0.04)
	cheeks = p.blob((0, -0.2, 0.0), 0.08, squash=(1.1, 1.0, 0.6), subdiv=1, rough=0.02)
	p.paint(cheeks, BELLY, "LIGHT")
	nose = p.blob((0, -0.385, 0.035), 0.03, subdiv=1, rough=0.0)
	p.paint(nose, "noche", "MID")
	for side in (-1, 1):
		ear = p.cylinder(0.065, 0.0, 0.17, sides=4, radius_top=0.004, phase=0.785)
		p.transform(ear, Matrix.Translation((side * 0.08, -0.04, 0.16)) @ Matrix.Rotation(side * -0.3, 4, "Y") @ Matrix.Scale(0.45, 4, Vector((0, 1, 0))))
		p.paint_bands(ear, [(0.27, 0.4, DARK, "MID")], default=(0, 0, RUST, "DARK"))
		eye = p.blob((side * 0.085, -0.19, 0.08), 0.026, squash=(1.0, 0.6, 1.0), subdiv=1, rough=0.0)
		p.paint(eye, "noche", "MID")
		glint = p.blob((side * 0.09, -0.205, 0.088), 0.009, subdiv=1, rough=0.0)
		p.paint(glint, "fuego", "LIGHT")


def mandibula(p):
	"""La mandíbula, desde la bisagra hacia -Y: blanca por abajo, con colmillos."""
	jaw = p.cylinder(0.055, 0.0, 0.2, sides=6, radius_top=0.025)
	p.transform(jaw, Matrix.Rotation(1.57, 4, "X") @ Matrix.Scale(0.6, 4, Vector((0, 1, 0))))
	p.paint(jaw, BELLY, "MID")
	fangs = []
	for side in (-1, 1):
		fangs += p.cylinder(0.012, 0.0, 0.04, sides=4, radius_top=0.002, center=(side * 0.025, -0.17))
	p.paint(fangs, "blanco", "LIGHT")


def pata(p, back):
	"""Pata desde el hombro o la cadera (el origen) hasta el piso (z -0.5): muslo, caña fina y pie oscuro."""
	if back:
		thigh = p.blob((0, 0.03, -0.1), 0.11, squash=(0.7, 1.0, 1.3), subdiv=2, rough=0.03)
		p.paint(thigh, BACK, "MID", vary=0.05)
		shin = p.cylinder(0.04, -0.46, -0.16, sides=6, radius_top=0.05)
		p.transform(shin, Matrix.Translation((0, 0.05, 0)))
	else:
		upper = p.blob((0, 0, -0.08), 0.09, squash=(0.7, 0.9, 1.4), subdiv=2, rough=0.03)
		p.paint(upper, RUST, "MID", vary=0.05)
		shin = p.cylinder(0.038, -0.46, -0.12, sides=6, radius_top=0.045)
	p.paint(shin, RUST, "DARK", vary=0.05)
	paw = p.blob((0, -0.03, -0.47), 0.05, squash=(0.9, 1.3, 0.6), subdiv=1, rough=0.02)
	p.paint(paw, DARK, "MID")


def cola(p):
	"""Cola peluda desde la base hacia +Y y abajo, gris con la punta negra."""
	parts = []
	for i, (y, z, r) in enumerate(((0.08, -0.02, 0.07), (0.2, -0.07, 0.1), (0.33, -0.12, 0.11), (0.45, -0.16, 0.1))):
		parts.append(p.blob((0, y, z), r, squash=(0.9, 1.3, 0.9), subdiv=2, rough=0.05))
	for faces in parts[:-1]:
		p.paint(faces, BACK, "MID", vary=0.06)
	p.paint(parts[-1], DARK, "MID")
	for side in (-1, 1):
		tuft(p, (side * 0.05, 0.3, -0.1), (side * 0.12, 0.44, -0.18), 0.06, BACK, "LOW")
	tuft(p, (0, 0.45, -0.16), (0, 0.6, -0.22), 0.07, DARK, "MID")
	CHAINS["atoq_cola"] = [[[0, 0, 0], godot(Vector((0, 0.2, -0.07))), godot(Vector((0, 0.38, -0.13))), godot(Vector((0, 0.6, -0.22)))]]



CHAINS = {}


def tuft(p, base, tip, radius, swatch, shade="MID", chain=None, flat=0.45):
	"""Mechón: gota aplastada de base a tip; con chain, guarda su cadena de huesos (en ejes de Godot)."""
	base, tip = Vector(base), Vector(tip)
	d = tip - base
	length = d.length
	f = p.lathe([(radius * 0.6, 0.0), (radius, length * 0.3), (radius * 0.75, length * 0.65), (radius * 0.3, length * 0.9), (0.0, length)], sides=6)
	p.transform(f, Matrix.Translation(base) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4() @ Matrix.Scale(flat, 4, Vector((1, 0, 0))))
	p.paint(f, swatch, shade, vary=0.06)
	if chain is not None:
		chain.append([godot(base), godot(tip)])
	return f


def godot(v):
	return [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]


def pelo_cuerpo(p):
	"""Melena del pecho (blanca al frente, rojiza a los costados), flecos en la panza y mechones grises acostados sobre
	el lomo."""
	chains = CHAINS.setdefault("atoq_pelo_cuerpo", [])
	for x in (-0.06, 0.0, 0.06):
		tuft(p, (x, -0.41, 0.03), (x * 1.6, -0.43, -0.16 + abs(x)), 0.06, BELLY, "LIGHT", chains)
	for side in (-1, 1):
		tuft(p, (side * 0.12, -0.36, 0.08), (side * 0.22, -0.28, -0.04), 0.06, BELLY, "MID", chains)
		tuft(p, (side * 0.14, -0.28, 0.17), (side * 0.25, -0.16, 0.12), 0.06, RUST, "MID", chains)
		for y in (-0.05, 0.12):
			tuft(p, (side * 0.12, y, -0.12), (side * 0.15, y + 0.1, -0.24), 0.06, BELLY, "MID", chains)
	for y in (-0.2, -0.06, 0.08, 0.22):
		for side in (-1, 1):
			tuft(p, (side * 0.05, y, 0.15), (side * 0.07, y + 0.2, 0.15), 0.06, BACK, "LOW", chains)


def pelo_cabeza(p):
	"""Mechones blancos en los cachetes y un copete rojizo entre las orejas."""
	chains = CHAINS.setdefault("atoq_pelo_cabeza", [])
	for side in (-1, 1):
		tuft(p, (side * 0.11, -0.13, 0.0), (side * 0.22, -0.04, -0.05), 0.045, BELLY, "LIGHT", chains)
		tuft(p, (side * 0.12, -0.08, -0.03), (side * 0.2, 0.02, -0.1), 0.04, BELLY, "MID", chains)
	tuft(p, (0, -0.04, 0.17), (0, 0.06, 0.25), 0.05, RUST, "MID", chains)

piece("atoq_cuerpo", 1, cuerpo)
piece("atoq_cabeza", 2, cabeza)
piece("atoq_mandibula", 3, mandibula)
piece("atoq_pata_del", 4, lambda p: pata(p, False))
piece("atoq_pata_tras", 5, lambda p: pata(p, True))
piece("atoq_cola", 6, cola)
piece("atoq_pelo_cuerpo", 7, pelo_cuerpo)
piece("atoq_pelo_cabeza", 8, pelo_cabeza)
with open(os.path.join(epi.ROOT, "art", "blender", "atoq_pelo.json"), "w") as out:
	json.dump(CHAINS, out, indent="\t")

epi.layout(kit, columns=8, spacing=1.2)
epi.publish("atoq")
