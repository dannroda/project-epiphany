# Publica assets/epiphany/paredes_la.glb: paredes de mazmorra a lo Link's Awakening (prueba sobre la Chullpa).
# Cada pieza es una celda de pared que baja en rampa hacia los lados con piso, para que con la cámara casi cenital se vean las
# cuatro caras de la sala: la norte empinada y alta, la sur tendida (se ve desde arriba), las de los costados a 63°.
# Las formas salen de tools/paredes_la.json (godot ... tools/la_walls.gd -- export): lados con piso (n e s o) y esquinas sueltas.
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


def wall(code):
	parts = code.split("_")
	sides = [] if parts[0] == "x" else list(parts[0])
	corners = parts[1:]
	p = epi.Piece(sum(map(ord, code)))
	at = [0.5 * t + 0.5 * math.sin(t * math.pi / 2) for t in (-1 + 2 * i / N for i in range(N + 1))]
	grid = [[p.bm.verts.new((x, y, height(x, y, sides, corners))) for x in at] for y in at]
	faces = [p.bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])) for j in range(N) for i in range(N)]
	crest = []
	for f in faces:
		f.normal_update()
		c = f.calc_center_median()
		if f.normal.z > 0.95 and c.z > HEIGHT - 0.05:
			crest.append(f)
		else:
			t = course_tone(c)
			p.paint([f], STONE, z_range=(c.z - t * 2.0, c.z + (1 - t) * 2.0))
	p.paint(crest, "piedra", "MID", vary=0.08)
	top = [f.calc_center_median() for f in crest]
	rocks = []
	for c in top:
		if p.rng.random() > 0.12:
			continue
		rocks += p.blob((c.x, c.y, HEIGHT), p.rng.uniform(0.14, 0.22), squash=(1.1, 1.0, 0.6), subdiv=1, rough=0.25, flat_bottom=HEIGHT)
	p.paint(rocks, "piedra", z_range=(HEIGHT - 0.1, HEIGHT + 0.25), vary=0.1)
	p.build("pared_la_" + code, kit)


for code in json.load(open(os.path.join(ROOT, "tools", "paredes_la.json"))):
	wall(code)
epi.layout(kit, columns=6, spacing=3.0)
epi.publish("paredes_la")
