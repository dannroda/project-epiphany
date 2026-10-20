# Voz del jefe final (11.50): sintetiza sus sonidos a assets/audio/sfx/boss/*.ogg (Feel.SAMPLES) y un preview.wav
# en debug/tmp/ para escucharlos seguidos. Necesita numpy y ffmpeg con libvorbis.
# python3 tools/audio/render_boss_sfx.py
import os
import subprocess
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "audio", "sfx", "boss")
PREVIEW = os.path.join(ROOT, "debug", "tmp", "boss_audio", "preview.wav")
RATE = 44100
PEAK = 0.89


def timeline(seconds):
	return np.arange(int(seconds * RATE)) / RATE


def phase(freq):
	return 2 * np.pi * np.cumsum(freq) / RATE


def lowpass(x, cutoff):
	"""Un polo, `cutoff` en Hz (fijo o por muestra)."""
	a = 1 - np.exp(-2 * np.pi * np.broadcast_to(np.asarray(cutoff, float), x.shape) / RATE)
	y = np.empty_like(x)
	acc = 0.0
	for i in range(len(x)):
		acc += a[i] * (x[i] - acc)
		y[i] = acc
	return y


def resonator(x, freq, decay):
	"""Biquad de dos polos: suena en `freq` y se apaga en ~`decay` segundos."""
	r = np.exp(-1 / (decay * RATE))
	c = 2 * r * np.cos(2 * np.pi * freq / RATE)
	y = np.zeros_like(x)
	y1 = y2 = 0.0
	for i in range(len(x)):
		v = x[i] + c * y1 - r * r * y2
		y[i] = v
		y2, y1 = y1, v
	return y * (1 - r)


def saw(ph, harmonics=24):
	return sum(np.sin(ph * n) / n for n in range(1, harmonics + 1)) * 0.6


def env(t, attack, release, length):
	return np.clip(t / attack, 0, 1) * np.clip((length - t) / release, 0, 1)


def normalized(x, peak=PEAK):
	return x / np.max(np.abs(x)) * peak


def hum():
	"""Zumbido de fondo, loop de 8 s: un motor grave que late (todas las frecuencias cierran ciclos en 8 s)."""
	t = timeline(8.0)
	base = sum(np.sin(2 * np.pi * 55 * n * t) / n ** 1.3 for n in range(1, 9))
	beat = np.sin(2 * np.pi * 55.25 * t) * 0.5 + np.sin(2 * np.pi * 110.125 * t) * 0.25
	servo = np.sin(2 * np.pi * 330 * t + 2 * np.sin(2 * np.pi * 0.5 * t)) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.25 * t)) ** 3 * 0.12
	rng = np.random.default_rng(3)
	noise = np.tile(rng.standard_normal(len(t)), 2)
	noise = lowpass(noise, 400)[len(t):] * 0.35
	breath = 0.75 + 0.25 * np.sin(2 * np.pi * 0.125 * t)
	return normalized((base * 0.6 + beat * 0.5 + servo + noise) * breath, 0.7)


def lid(seed):
	"""Chirrido de párpados: piedra que roza (stick-slip) por resonancias de metal."""
	rng = np.random.default_rng(seed)
	length = 0.62
	t = timeline(length)
	pulses = np.zeros_like(t)
	at = 0.02
	while at < length - 0.03:
		pulses[int(at * RATE)] = rng.uniform(0.6, 1.0)
		at += 1 / rng.uniform(28, 70)
	body = sum(resonator(pulses, f * rng.uniform(0.95, 1.05), d) * g for f, d, g in ((430, 0.05, 1.0), (790, 0.04, 0.7), (1370, 0.03, 0.5), (2210, 0.02, 0.3)))
	grind = lowpass(rng.standard_normal(len(t)), 900) * 0.25
	swell = np.sin(np.pi * np.clip(t / length, 0, 1)) ** 0.7
	return normalized((body * 6 + grind) * swell, 0.75)


def charge(length, start, end, buzz):
	"""Carga: un tono que sube y late cada vez más rápido, como el iris (Boss.charging)."""
	t = timeline(length)
	p = t / length
	freq = start * (end / start) ** p
	ph = phase(freq)
	tone = np.sin(ph) + 0.35 * np.sin(ph * 2.01) + buzz * saw(ph, 10)
	beat = 0.5 + 0.5 * np.sin(p * p * 14 * np.pi)
	rng = np.random.default_rng(int(length * 100))
	suck = lowpass(rng.standard_normal(len(t)), 600 + 5000 * p) * p ** 2 * 0.5
	shimmer = np.sin(phase(freq * 4.02)) * 0.12 * p
	out = (tone * (0.35 + 0.65 * beat) + suck + shimmer) * (0.25 + 0.75 * p) * env(t, 0.03, 0.02, length)
	return normalized(out, 0.8)


def roar():
	"""Rugido de fase: gruñido grave con formantes, sub y un anillo metálico encima."""
	length = 1.7
	t = timeline(length)
	contour = np.interp(t, [0, 0.25, 1.0, length], [44, 62, 55, 38])
	ph = phase(contour)
	rng = np.random.default_rng(7)
	source = saw(ph, 40) + rng.standard_normal(len(t)) * 0.35
	voice = resonator(source, 320, 0.02) * 3 + resonator(source, 720, 0.015) * 2 + resonator(source, 2500, 0.008) * 0.6
	ring = np.sin(phase(contour * 3.17)) * saw(ph, 6) * 0.25
	sub = np.sin(phase(contour * 0.5)) * 0.6
	growl = 0.75 + 0.25 * np.sin(2 * np.pi * 23 * t)
	out = (voice * growl + ring + sub) * env(t, 0.07, 0.6, length)
	return normalized(np.tanh(normalized(out, 1.0) * 1.6), PEAK)


def slam(seed):
	"""Golpe de la mano: sub que cae, polvo y un clang de hierro."""
	rng = np.random.default_rng(seed)
	length = 1.3
	t = timeline(length)
	sub = np.sin(phase(32 + 70 * np.exp(-t * 9) * rng.uniform(0.9, 1.1))) * np.exp(-t * 3.5)
	thump = lowpass(rng.standard_normal(len(t)), 500) * np.exp(-t * 14) * 1.6
	hit = np.zeros_like(t)
	hit[0] = 1.0
	clang = sum(resonator(hit, f * rng.uniform(0.97, 1.03), d) * g for f, d, g in ((196, 0.9, 1.0), (353, 0.6, 0.8), (527, 0.45, 0.6), (811, 0.3, 0.4), (1290, 0.18, 0.25)))
	out = sub * 1.2 + thump + clang * 9
	return normalized(np.tanh(normalized(out, 1.0) * 1.3), PEAK)


def eye_hit(seed):
	"""Golpe al ojo aturdido: un golpe seco con grave y el chillido eléctrico del ojo."""
	rng = np.random.default_rng(seed)
	length = 0.55
	t = timeline(length)
	thud = np.sin(phase(50 + 90 * np.exp(-t * 18))) * np.exp(-t * 9)
	crack = lowpass(rng.standard_normal(len(t)), 2500) * np.exp(-t * 40) * 0.8
	squeal = np.sin(phase(np.interp(t, [0, 0.05, length], [900, 700, 280]) * rng.uniform(0.92, 1.08)))
	squeal = squeal * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 38 * t))) * np.clip((t - 0.02) / 0.03, 0, 1) * np.exp(-t * 7) * 0.35
	return normalized(thud * 1.1 + crack + squeal, PEAK)


def save(name, x, loop=False):
	os.makedirs(OUT, exist_ok=True)
	pcm = os.path.join(OUT, name + ".wav")
	with wave.open(pcm, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(RATE)
		w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
	subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", pcm, "-c:a", "libvorbis", "-q:a", "6", os.path.join(OUT, name + ".ogg")], check=True)
	os.remove(pcm)
	return x


def main():
	sounds = []
	sounds.append(save("boss_hum", hum(), loop=True)[: RATE * 4])
	for i in range(3):
		sounds.append(save("boss_lid_%d" % i, lid(10 + i)))
	sounds.append(save("boss_orb_charge", charge(0.8, 180, 950, 0.0)))
	sounds.append(save("boss_laser_charge", charge(1.0, 110, 620, 0.5)))
	sounds.append(save("boss_roar", roar()))
	for i in range(3):
		sounds.append(save("boss_slam_%d" % i, slam(20 + i)))
	for i in range(3):
		sounds.append(save("boss_eye_hit_%d" % i, eye_hit(30 + i)))
	gap = np.zeros(int(RATE * 0.5))
	os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
	with wave.open(PREVIEW, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(RATE)
		w.writeframes((np.clip(np.concatenate([np.concatenate([s, gap]) for s in sounds]), -1, 1) * 32767).astype("<i2").tobytes())
	print("ok", PREVIEW)


if __name__ == "__main__":
	main()
