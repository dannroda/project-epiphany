# godot --headless --path . --script res://tools/render_feel_sfx.gd
extends SceneTree
## Renderiza una vez a assets/audio/sfx/synth/*.wav los sonidos de Feel que no tienen muestra grabada (antes se
## sintetizaban en cada arranque). Feel los carga como cualquier otra muestra.

const OUT := "res://assets/audio/sfx/synth/"
const RATE := 22050


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	seed(7)
	var recipes := {
		&"boom": [0.6, func(t: float) -> float: return ((randf() * 2.0 - 1.0) * 0.7 + sin(TAU * lerpf(90.0, 40.0, t / 0.6) * t) * 0.5) * exp(-t * 6.0)],
		&"secret": [0.9, func(t: float) -> float: return sin(TAU * [392.0, 440.0, 523.0, 659.0, 784.0, 1047.0][mini(int(t / 0.15), 5)] * t) * 0.25 * exp(-fmod(t, 0.15) * 6.0)],
		&"rumble": [1.2, func(t: float) -> float: return ((randf() * 2.0 - 1.0) * 0.3 + sin(TAU * 38.0 * t) * 0.45) * sin(PI * t / 1.2)],
		&"item_get": [1.3, func(t: float) -> float: return 0.22 * (sin(TAU * [392.0, 523.0, 659.0, 784.0][mini(int(t / 0.09), 3)] * t) * exp(-fmod(t, 0.09) * 10.0) if t < 0.36 else (sin(TAU * 1047.0 * t) + 0.7 * sin(TAU * 1319.0 * t) + 0.5 * sin(TAU * 1568.0 * t)) * 0.5 * exp(-(t - 0.36) * 2.5) * minf(1.0, (t - 0.36) * 60.0))],
		&"drip": [0.12, func(t: float) -> float: return sin(TAU * lerpf(700.0, 1700.0, minf(t / 0.04, 1.0)) * t) * 0.3 * exp(-t * 35.0)],
		&"splash": [0.45, func(t: float) -> float: return ((randf() * 2.0 - 1.0) * 0.45 * exp(-t * 9.0) + sin(TAU * lerpf(160.0, 70.0, t / 0.45) * t) * 0.35 * exp(-t * 14.0)) * minf(1.0, t * 200.0)],
		&"wade": [0.16, func(t: float) -> float: return (randf() * 2.0 - 1.0) * 0.18 * sin(PI * t / 0.16) * exp(-t * 8.0)],
		&"roar": [1.4, func(t: float) -> float: return (fmod(lerpf(70.0, 125.0, sin(PI * t / 1.4)) * t, 1.0) * 0.7 - 0.35 + (randf() * 2.0 - 1.0) * 0.28) * (0.7 + 0.3 * sin(TAU * 27.0 * t)) * minf(1.0, t * 12.0) * minf(1.0, (1.4 - t) * 2.5)],
		&"warp_out": [0.55, func(t: float) -> float: return signf(sin(TAU * lerpf(220.0, 1500.0, pow(t / 0.55, 1.5)) * t)) * 0.16 * (0.6 + 0.4 * sin(TAU * 30.0 * t)) * minf(1.0, (0.55 - t) * 8.0)],
		&"warp_in": [0.5, func(t: float) -> float: return signf(sin(TAU * lerpf(1500.0, 260.0, minf(t / 0.2, 1.0)) * t)) * 0.16 * minf(1.0, t * 80.0) * exp(-maxf(t - 0.2, 0.0) * 9.0) + sin(TAU * 70.0 * t) * 0.35 * exp(-maxf(t - 0.18, 0.0) * 14.0) * (1.0 if t > 0.18 else 0.0)],
		&"heal": [0.45, func(t: float) -> float: return sin(TAU * [523.0, 659.0, 784.0][mini(int(t / 0.15), 2)] * t) * 0.3 * exp(-fmod(t, 0.15) * 12.0)],
	}
	for sound: StringName in recipes:
		var stream := _synth(recipes[sound][0], recipes[sound][1])
		stream.save_to_wav(OUT + String(sound) + ".wav")
	quit()


func _synth(seconds: float, wave: Callable) -> AudioStreamWAV:
	var samples := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var value := clampf(wave.call(float(i) / RATE), -1.0, 1.0)
		data.encode_s16(i * 2, int(value * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
