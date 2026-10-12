# Publica assets/epiphany/paredes_la.glb: paredes de mazmorra a lo Link's Awakening (prueba sobre la Chullpa).
# Cada pieza es una celda de pared que baja en rampa hacia los lados con piso, para que con la cámara casi cenital se vean las
# cuatro caras de la sala: la norte empinada y alta, la sur tendida (se ve desde arriba), las de los costados a 63°.
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
## Ancho de la rampa según hacia dónde está el piso: piso al sur = cara que mira a la cámara.
RUN = {"s": 0.5, "n": 1.5, "e": 1.0, "o": 1.0}
STONE = "acantilado"
kit = epi.start()


def dist(x, y, side):
	return {"n": 1 - y, "s": y + 1, "e": 1 - x, "o": x + 1}[side]


def ramp(d, run):
	return max(0.0, min(1.0, d / run))


def height(x, y, sides, corners):
	f = 1.0
	for side in sides:
		f = min(f, ramp(dist(x, y, side), RUN[side]))
	for c in corners:
		f = min(f, max(ramp(dist(x, y, c[0]), RUN[c[0]]), ramp(dist(x, y, c[1]), RUN[c[1]])))
	return HEIGHT * f


def course_tone(c):
	"""Hiladas de piedra en la rampa: tono por hilada y por bloque, para que se lea mampostería."""
	row = math.floor(c.z / 0.45)
	along = c.x + c.y + row * 0.37
	block = math.floor(along / 0.7)
	return 0.28 + 0.42 * random.Random(block * 7919 + row * 104729).random()


HALF = 0.7
STEP_START = 0.4
STEP_RUN = 0.3
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
				shade(p, f, "piedra" if cut == "sube" else "gris_4", max(0.06, 0.6 - 0.45 * d / 1.6))
		elif inside and abs(f.normal.x if across_x(sides, cut) else f.normal.y) < 0.5:
			shade(p, f, "piedra" if cut != "baja" else "gris_5", max(0.05, 0.3 - 0.2 * inside[0] / 1.6))
		elif f.normal.z > 0.95 and c.z > HEIGHT - 0.05:
			crest.append(f)
		else:
			shade(p, f, STONE, course_tone(c))
	p.paint(crest, "piedra", "MID", vary=0.08)
	rocks = []
	for f in crest:
		if p.rng.random() > 0.12:
			continue
		c = f.calc_center_median()
		rocks += p.blob((c.x, c.y, HEIGHT), p.rng.uniform(0.14, 0.22), squash=(1.1, 1.0, 0.6), subdiv=1, rough=0.25, flat_bottom=HEIGHT)
	p.paint(rocks, "piedra", z_range=(HEIGHT - 0.1, HEIGHT + 0.25), vary=0.1)
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
