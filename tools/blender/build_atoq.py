# Publica assets/epiphany/atoq.glb (epi.publish): el atoq, el zorro andino de la Cumbre (11.196). Piezas rígidas, cada
# una con el origen donde gira, que atoq_model.tscn cuelga de sus pivotes y anima: atoq_cuerpo (centro del cuerpo),
# atoq_cabeza (la nuca), atoq_mandibula (la bisagra), atoq_pata_del / atoq_pata_tras (hombro y cadera, hacia abajo) y
# atoq_cola (la base, hacia atrás). El hocico mira a -Y (+Z en Godot, como los modelos de KayKit que usa Enemy). Pelaje gris con la cabeza y las patas rojizas, pecho y panza
# blancos, la punta de la cola negra.
# blender -b --factory-startup -P tools/blender/build_atoq.py
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


piece("atoq_cuerpo", 1, cuerpo)
piece("atoq_cabeza", 2, cabeza)
piece("atoq_mandibula", 3, mandibula)
piece("atoq_pata_del", 4, lambda p: pata(p, False))
piece("atoq_pata_tras", 5, lambda p: pata(p, True))
piece("atoq_cola", 6, cola)

epi.layout(kit, columns=6, spacing=1.2)
epi.publish("atoq")
