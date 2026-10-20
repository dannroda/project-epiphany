# Tema del jefe final (11.50): tres capas en loop de 16 s (8 compases a 120 bpm, Re menor) a assets/audio/music/boss_*.wav
# para Music: boss_drums (bombo, tic del mecanismo, bajo) desde la fase 1, boss_theme (quena y colchón) desde la 2 y
# boss_fury (bajo saturado, redoblante, coro) en la 3. Lo que pasa del final del loop entra por el principio.
# También un preview.wav en debug/tmp/boss_audio/ con las tres fases seguidas. Necesita numpy.
# python3 tools/audio/render_boss_music.py
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "audio", "music")
PREVIEW = os.path.join(ROOT, "debug", "tmp", "boss_audio", "theme_preview.wav")
RATE = 32000
BEAT = 0.5
BARS = 8
LENGTH = BARS * 4 * BEAT
FRAMES = int(LENGTH * RATE)
## Raíz de cada compás: Rem Rem Sib Do Rem Rem Solm La.
ROOTS = [38, 38, 34, 36, 38, 38, 43, 45]
CHORDS = [[62, 65, 69], [62, 65, 69], [58, 62, 65], [60, 64, 67], [62, 65, 69], [62, 65, 69], [55, 58, 62], [57, 61, 64]]
## Quena: (compás, tiempo, nota MIDI, tiempos que dura).
MELODY = [
	(0, 0, 74, 1), (0, 1, 77, 0.5), (0, 1.5, 79, 0.5), (0, 2, 81, 2),
	(1, 0, 84, 0.5), (1, 0.5, 81, 0.5), (1, 1, 79, 1), (1, 2, 77, 1), (1, 3, 79, 1),
	(2, 0, 77, 1), (2, 1, 79, 0.5), (2, 1.5, 77, 0.5), (2, 2, 74, 2),
	(3, 0, 76, 1), (3, 1, 79, 1), (3, 2, 84, 1), (3, 3, 81, 1),
	(4, 0, 86, 1.5), (4, 1.5, 84, 0.5), (4, 2, 81, 1), (4, 3, 79, 1),
	(5, 0, 81, 1), (5, 1, 77, 0.5), (5, 1.5, 79, 0.5), (5, 2, 74, 2),
	(6, 0, 79, 1), (6, 1, 82, 1), (6, 2, 81, 0.5), (6, 2.5, 79, 0.5), (6, 3, 77, 1),
	(7, 0, 81, 1), (7, 1, 79, 0.5), (7, 1.5, 77, 0.5), (7, 2, 76, 1), (7, 3, 73, 1),
]


def hz(note):
	return 440.0 * 2 ** ((note - 69) / 12)


def at(bar, beat):
	return (bar * 4 + beat) * BEAT


def place(buffer, start, signal):
	"""Suma `signal` desde `start` (s); lo que se pasa del loop vuelve al principio."""
	i = int(start * RATE) % FRAMES
	n = len(signal)
	end = min(FRAMES, i + n)
	buffer[i:end] += signal[: end - i]
	if i + n > FRAMES:
		buffer[: i + n - FRAMES] += signal[end - i:]


def timeline(seconds):
	return np.arange(int(seconds * RATE)) / RATE


def lowpass(x, cutoff):
	a = 1 - np.exp(-2 * np.pi * cutoff / RATE)
	y = np.empty_like(x)
	acc = 0.0
	for i in range(len(x)):
		acc += a * (x[i] - acc)
		y[i] = acc
	return y


def circular_lowpass(x, cutoff):
	return lowpass(np.concatenate([x, x]), cutoff)[len(x):]


def saw(freq, t, harmonics):
	return sum(np.sin(2 * np.pi * freq * n * t) / n for n in range(1, harmonics + 1) if freq * n < RATE / 2.2)


def adsr(t, attack, release, length):
	return np.clip(t / attack, 0, 1) * np.clip((length - t) / release, 0, 1)


def bombo(accent):
	t = timeline(0.45)
	tone = np.sin(2 * np.pi * np.cumsum(48 + 80 * np.exp(-t * 30)) / RATE) * np.exp(-t * 7)
	skin = np.random.default_rng(int(accent * 10)).standard_normal(len(t)) * np.exp(-t * 60) * 0.25
	return (tone + skin) * accent


def tick(accent, seed):
	t = timeline(0.06)
	noise = np.random.default_rng(seed).standard_normal(len(t))
	metal = np.sin(2 * np.pi * 3170 * t) * 0.6 + np.sin(2 * np.pi * 4730 * t) * 0.4
	return (noise * 0.4 + metal) * np.exp(-t * 90) * accent


def bass(note, seconds):
	t = timeline(seconds)
	f = hz(note)
	return (np.sin(2 * np.pi * f * t) + 0.35 * saw(f, t, 6)) * adsr(t, 0.008, 0.06, seconds)


def quena(note, beats):
	seconds = beats * BEAT
	t = timeline(seconds + 0.12)
	f = hz(note)
	vibrato = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.18) / 0.2, 0, 1)
	ph = 2 * np.pi * np.cumsum(f * vibrato) / RATE
	tone = np.sin(ph) + 0.28 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
	rng = np.random.default_rng(note)
	breath = lowpass(rng.standard_normal(len(t)), 3500) * 0.12 * (0.6 + 0.4 * np.exp(-t * 12))
	return (tone + breath) * adsr(t, 0.035, 0.12, seconds + 0.12)


def pad(chord, seconds):
	t = timeline(seconds + 0.4)
	out = sum(saw(hz(n) * d, t, 8) for n in chord for d in (0.997, 1.003))
	return out * adsr(t, 0.4, 0.5, seconds + 0.4) / (len(chord) * 2)


def snare(seed):
	t = timeline(0.25)
	noise = np.random.default_rng(seed).standard_normal(len(t))
	body = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25)
	return (noise * np.exp(-t * 18) * 0.7 + body * 0.6)


def choir(chord, seconds):
	t = timeline(seconds)
	out = np.zeros_like(t)
	for n in chord:
		f = hz(n - 12)
		out += saw(f, t, 30) * (1 + 0.3 * np.sin(2 * np.pi * 4.7 * t))
	return out * adsr(t, 0.05, 0.25, seconds) / len(chord)


def normalized(x, peak):
	return x / np.max(np.abs(x)) * peak


def drums():
	buffer = np.zeros(FRAMES)
	pattern = [(0, 1.0), (0.75, 0.6), (1.5, 0.8), (2, 1.0), (2.75, 0.6), (3.5, 0.7)]
	for bar in range(BARS):
		for beat, accent in pattern:
			place(buffer, at(bar, beat), bombo(accent))
		for eighth in range(8):
			place(buffer, at(bar, eighth * 0.5), tick(0.35 if eighth % 2 == 0 else 0.6, bar * 8 + eighth) * 0.5)
		for eighth in range(8):
			note = ROOTS[bar] + (12 if eighth in (3, 6) else 0)
			place(buffer, at(bar, eighth * 0.5), bass(note, BEAT * 0.45) * 0.55)
	return normalized(buffer, 0.5)


def theme():
	buffer = np.zeros(FRAMES)
	for bar in range(BARS):
		place(buffer, at(bar, 0), pad(CHORDS[bar], 4 * BEAT) * 0.5)
	pads = circular_lowpass(buffer, 1400)
	melody = np.zeros(FRAMES)
	for bar, beat, note, beats in MELODY:
		place(melody, at(bar, beat), quena(note, beats))
	return normalized(pads * 0.7 + normalized(melody, 1.0) * 0.6, 0.45)


def fury():
	buffer = np.zeros(FRAMES)
	for bar in range(BARS):
		for sixteenth in range(16):
			note = ROOTS[bar] - 12 + (12 if sixteenth % 4 == 2 else 0)
			place(buffer, at(bar, sixteenth * 0.25), bass(note, BEAT * 0.22) * 0.6)
		for beat in (1, 3):
			place(buffer, at(bar, beat), snare(bar * 4 + beat) * 0.5)
		for sixteenth in range(16):
			place(buffer, at(bar, sixteenth * 0.25), tick(0.5 if sixteenth % 2 else 0.25, 999 + bar * 16 + sixteenth) * 0.4)
		place(buffer, at(bar, 0), choir(CHORDS[bar], BEAT * 1.5) * 0.45)
	return normalized(np.tanh(normalized(buffer, 1.0) * 2.2), 0.45)


def write(path, x):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(RATE)
		w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())


def main():
	layers = {"boss_drums": drums(), "boss_theme": theme(), "boss_fury": fury()}
	for name, x in layers.items():
		write(os.path.join(OUT, name + ".wav"), x)
	d, t, f = layers["boss_drums"], layers["boss_theme"], layers["boss_fury"]
	write(PREVIEW, np.concatenate([d, d + t, d + t + f, d + t + f]) * 0.85)
	print("ok", PREVIEW)


if __name__ == "__main__":
	main()
