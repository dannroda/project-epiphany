# godot --headless --path . --script res://src/tools/render_music.gd
extends SceneTree
## Renderiza las capas de música (placeholder sintetizado) a assets/audio/music/*.wav: loops exactos de 8 s.
## Las frecuencias van redondeadas a múltiplos de 1/8 Hz para que cada voz cierre ciclos enteros y el loop no haga clic.

const OUT := "res://assets/audio/music/"
const RATE := 22050
const LENGTH := 8.0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_render("calm", func(t: float) -> float: return _pad(t, [130.81, 164.81, 196.0, 261.63]) * 0.22)
	_render("dark", func(t: float) -> float: return _pad(t, [110.0, 130.81, 164.81, 220.0, 110.1]) * 0.22)
	_render("pulse", func(t: float) -> float:
		var beat := fmod(t, 1.0)
		return sin(TAU * _q(55.0) * t) * exp(-beat * 7.0) * 0.5)
	var noise := [0.0]
	_render("murmur", func(t: float) -> float:
		noise[0] = lerpf(noise[0], randf() * 2.0 - 1.0, 0.04)
		var swell := pow(sin(PI * t / 4.0), 2.0)
		return noise[0] * swell * 1.6 + sin(TAU * _q(73.5) * t) * swell * 0.05)
	_render("heartbeat", func(t: float) -> float:
		var beat := fmod(t, 0.8)
		var lub := exp(-beat * 30.0) * sin(TAU * _q(52.0) * t)
		var dub := (exp(-(beat - 0.22) * 34.0) if beat >= 0.22 else 0.0) * sin(TAU * _q(46.0) * t)
		return (lub + dub * 0.8) * 0.6)
	quit()


func _q(frequency: float) -> float:
	return roundf(frequency * LENGTH) / LENGTH


## Acorde suave: cada voz con su armónico y un vaivén de volumen que cierra en 8, 4 u 8/3 s.
func _pad(t: float, notes: Array) -> float:
	var total := 0.0
	for i in notes.size():
		var f := _q(notes[i])
		var swell := 0.6 + 0.4 * sin(TAU * t * float(i % 3 + 1) / LENGTH + i)
		total += (sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t)) * swell
	return total / notes.size()


func _render(file: String, wave: Callable) -> void:
	var frames := int(RATE * LENGTH)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		data.encode_s16(i * 2, int(clampf(wave.call(float(i) / RATE), -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	print(file, " ", stream.save_to_wav(OUT + file + ".wav"))
