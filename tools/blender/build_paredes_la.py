# Publica assets/epiphany/paredes_la.glb: paredes de mazmorra a lo Link's Awakening (prueba sobre la Chullpa).
# Cada pieza es una celda de pared que baja en rampa hacia los lados con piso, igual en las cuatro caras de la sala.
# Las formas salen de tools/paredes_la.json (godot ... tools/la_walls.gd -- export): lados con piso (n e s o) y esquinas sueltas.
# Las puertas (paso) son la misma pared con un corte de 1.4 m; las escaleras (sube, baja) un corte ciego con escalones.
# blender -b -P tools/blender/build_paredes_la.py
import json
import math
import os
import random
import sys


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import epi  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HEIGHT = 2.0
N = 24
## Como en LA: las cuatro paredes con el mismo alto y la misma rampa (la sur esconde poco piso porque la cámara es casi
## cenital), y la cresta plana sigue igual en las esquinas.
RUN = 0.8
MARGIN = 2.0
STONE = "acantilado"
kit = epi.start()


def dist(x, y, side):
	return {"n": 1 - y, "s": y + 1, "e": 1 - x, "o": x + 1}[side]


def profile(d):
	return HEIGHT * max(0.0, min(1.0, d / RUN))


def height(x, y, sides, corners):
	"""Cada punto toma el perfil del lado o la esquina con piso más cercanos (a menos de MARGIN); si no hay ninguno, el alto."""
	near = [dist(x, y, side) for side in sides]
	near += [max(dist(x, y, c[0]), dist(x, y, c[1])) for c in corners]
	near = [d for d in near if d <= MARGIN]
	return profile(min(near)) if near else HEIGHT


def course_tone(c):
	"""Hiladas de piedra en la rampa: tono por hilada y por bloque, para que se lea mampostería."""
	row = math.floor(c.z / 0.45)
	along = c.x + c.y + row * 0.37
	block = math.floor(along / 0.7)
	return 0.28 + 0.42 * random.Random(block * 7919 + row * 104729).random()


HALF = 0.7
STEP_START = 0.3
STEP_RUN = 0.35
STEP_RISE = 0.25
STEPS = 4


def coord(side, d):
	return {"n": 1 - d, "s": d - 1, "e": 1 - d, "o": d - 1}[side]


def channel(x, y, sides, cut):
	"""Distancia desde la boca y si el punto cae dentro del corte; None si la pieza no tiene corte o el punto queda afuera."""
	if cut == "paso":
		across = x if "n" in sides or "s" in sides else y
		return (0.0, True) if abs(across) < HALF else None
	side = sides[0]
	across = y if side in "eo" else x
	return (dist(x, y, side), True) if abs(across) < HALF else None


def cut_height(d, cut):
	if cut == "paso" or d < STEP_START:
		return 0.0
	k = min(STEPS, math.floor((d - STEP_START) / STEP_RUN) + 1)
	return STEP_RISE * k * (1 if cut == "sube" else -1)


def across_x(sides, cut):
	return ("n" in sides or "s" in sides) if cut == "paso" else sides[0] in "ns"


def axes(sides, cut):
	base = [0.5 * t + 0.5 * math.sin(t * math.pi / 2) for t in (-1 + 2 * i / N for i in range(N + 1))]
	xs, ys = set(base), set(base)
	if cut:
		for b in (-HALF, -HALF + 0.01, HALF - 0.01, HALF):
			(xs if across_x(sides, cut) else ys).add(b)
		if cut != "paso":
			side = sides[0]
			for k in range(STEPS + 1):
				d = STEP_START + k * STEP_RUN
				for b in (d - 0.01, d):
					(ys if side in "ns" else xs).add(coord(side, b))
	return sorted(xs), sorted(ys)


def piece(kind, code, cut=None):
	parts = code.split("_")
	sides = [] if parts[0] == "x" else list(parts[0])
	corners = parts[1:]
	p = epi.Piece(sum(map(ord, kind + code)))
	xs, ys = axes(sides, cut)

	def h(x, y):
		inside = channel(x, y, sides, cut) if cut else None
		return cut_height(inside[0], cut) if inside else height(x, y, sides, corners)

	grid = [[p.bm.verts.new((x, y, h(x, y))) for x in xs] for y in ys]
	faces = [p.bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])) for j in range(len(ys) - 1) for i in range(len(xs) - 1)]
	crest = []
	for f in faces:
		f.normal_update()
		c = f.calc_center_median()
		inside = channel(c.x, c.y, sides, cut) if cut else None
		if inside and f.normal.z > 0.9:
			d = inside[0]
			if cut == "paso":
				shade(p, f, "tierra", 0.4)
			elif d > STEP_START + STEPS * STEP_RUN:
				p.paint([f], "noche", "DARK")
			else:
				shade(p, f, "piedra" if cut == "sube" else "gris_4", max(0.06, 0.6 - 0.45 * d / 1.7))
		elif inside and abs(f.normal.x if across_x(sides, cut) else f.normal.y) < 0.5:
			shade(p, f, "piedra" if cut != "baja" else "gris_5", max(0.05, 0.3 - 0.2 * inside[0] / 1.7))
		elif c.z > 0.3 and f.normal.z > 0.95:
			crest.append(f)
		else:
			shade(p, f, STONE, course_tone(c))
	p.paint(crest, "piedra", "MID", vary=0.08)
	rocks = []
	for f in crest:
		if p.rng.random() > 0.12:
			continue
		c = f.calc_center_median()
		r = p.rng.uniform(0.1, 0.16)
		rocks += p.blob((c.x, c.y, c.z), r, squash=(1.1, 1.0, 0.6), subdiv=1, rough=0.25, flat_bottom=c.z)
	p.paint(rocks, "piedra", "MID", vary=0.12)
	p.build("%s_la_%s" % (kind, code), kit)


def shade(p, f, swatch, t):
	c = f.calc_center_median()
	p.paint([f], swatch, z_range=(c.z - t * 2.0, c.z + (1 - t) * 2.0))


shapes = json.load(open(os.path.join(ROOT, "tools", "paredes_la.json")))
for code in shapes["pared"]:
	piece("pared", code)
for kind in ("paso", "sube", "baja"):
	for code in shapes[kind]:
		piece(kind, code, kind)
epi.layout(kit, columns=6, spacing=3.0)
epi.publish("paredes_la")
