extends SceneTree
## Genera las tres texturas del agua LA (cáusticas, olas, ondulación) en src/world/water/, repetibles.
## godot --headless --script res://tools/water_la_textures.gd [-- --ref=<carpeta>]  (con --ref imprime la comparación)

const SIZE := 512
const OUT := "res://src/world/water/water_la_%s.png"

## Celdas por lado; ancho de la línea y brillo en píxeles / valor.
const CAUSTIC_CELLS := 4
const CAUSTIC_WARP := 28.0
const CAUSTIC_WIDTH := 10.0
const CAUSTIC_PEAK := 0.58
const CAUSTIC_BLUR := 8

const WAVE_FREQUENCY := 0.03
const WAVE_OCTAVES := 4
const WAVE_BUMP := 1.7
const WAVE_BLUR := 2

const RIPPLE_FREQUENCY := 0.012
const RIPPLE_WARP := 45.0
const RIPPLE_BUMP := 2.3
const RIPPLE_BLUR := 3


func _init() -> void:
	var images := {"caustics": _caustics(), "waves": _waves(), "indirect": _ripples()}
	for name in images:
		images[name].save_png(OUT % name)
	var ref := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ref="):
			ref = a.substr(6)
	if ref != "":
		var refs := {"caustics": "caustic_a", "waves": "water_a", "indirect": "indirect_a"}
		for name in images:
			var other := Image.load_from_file("%s/%s.png" % [ref, refs[name]])
			print(name, " nuestro ", _stats(images[name]), " ref ", _stats(other))
	quit()


func _caustics() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var cell := float(SIZE) / CAUSTIC_CELLS
	var points: Array[Vector2] = []
	for j in CAUSTIC_CELLS:
		for i in CAUSTIC_CELLS:
			points.append(Vector2(i + rng.randf_range(0.15, 0.85), j + rng.randf_range(0.15, 0.85)) * cell)
	var warp := FastNoiseLite.new()
	warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warp.frequency = 0.012
	warp.fractal_octaves = 1
	warp.seed = 5
	var wx := warp.get_seamless_image(SIZE, SIZE, false, false, 0.1, true)
	warp.seed = 6
	var wy := warp.get_seamless_image(SIZE, SIZE, false, false, 0.1, true)
	warp.seed = 9
	var shade := warp.get_seamless_image(SIZE, SIZE, false, false, 0.1, true)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x + (wx.get_pixel(x, y).r - 0.5) * 2.0 * CAUSTIC_WARP, y + (wy.get_pixel(x, y).r - 0.5) * 2.0 * CAUSTIC_WARP)
			var ci := int(floor(p.x / cell))
			var cj := int(floor(p.y / cell))
			var d1 := INF
			var d2 := INF
			for oj in range(-2, 3):
				for oi in range(-2, 3):
					var i := ci + oi
					var j := cj + oj
					var wrap := Vector2(floor(float(i) / CAUSTIC_CELLS), floor(float(j) / CAUSTIC_CELLS)) * SIZE
					var q: Vector2 = points[posmod(j, CAUSTIC_CELLS) * CAUSTIC_CELLS + posmod(i, CAUSTIC_CELLS)] + wrap
					var d := p.distance_to(q)
					if d < d1:
						d2 = d1
						d1 = d
					elif d < d2:
						d2 = d
			var e := (d2 - d1) / CAUSTIC_WIDTH
			var v := CAUSTIC_PEAK * exp(-e * e) * lerpf(0.2, 1.0, pow(shade.get_pixel(x, y).r, 1.5))
			img.set_pixel(x, y, Color(v, v, v))
	return _blur(img, CAUSTIC_BLUR)


func _waves() -> Image:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 7
	noise.frequency = WAVE_FREQUENCY
	noise.fractal_octaves = WAVE_OCTAVES
	noise.fractal_gain = 0.5
	return _normal(_blur(noise.get_seamless_image(SIZE, SIZE, false, false, 0.1, true), WAVE_BLUR), WAVE_BUMP)


func _ripples() -> Image:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 21
	noise.frequency = RIPPLE_FREQUENCY
	noise.fractal_octaves = 2
	noise.domain_warp_enabled = true
	noise.domain_warp_amplitude = RIPPLE_WARP
	noise.domain_warp_frequency = 0.008
	noise.domain_warp_fractal_octaves = 1
	return _normal(_blur(noise.get_seamless_image(SIZE, SIZE, false, false, 0.1, true), RIPPLE_BLUR), RIPPLE_BUMP)


func _normal(height: Image, bump: float) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var dx := height.get_pixel((x + 1) % SIZE, y).r - height.get_pixel((x + SIZE - 1) % SIZE, y).r
			var dy := height.get_pixel(x, (y + 1) % SIZE).r - height.get_pixel(x, (y + SIZE - 1) % SIZE).r
			var n := Vector3(-dx * bump, -dy * bump, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	return img


## Caja repetida que da la vuelta en los bordes (para que siga repitiendo).
func _blur(src: Image, radius: int) -> Image:
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGBF)
	for pass_index in 2:
		for axis in 2:
			var out := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBF)
			for y in SIZE:
				for x in SIZE:
					var sum := Color(0, 0, 0)
					for k in range(-radius, radius + 1):
						var px := (x + k + SIZE) % SIZE if axis == 0 else x
						var py := (y + k + SIZE) % SIZE if axis == 1 else y
						sum += img.get_pixel(px, py)
					out.set_pixel(x, y, sum / float(radius * 2 + 1))
			img = out
	img.convert(Image.FORMAT_RGB8)
	return img


func _stats(img: Image) -> String:
	var mean := Vector3.ZERO
	var sq := Vector3.ZERO
	var grad := 0.0
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			var v := Vector3(c.r, c.g, c.b)
			mean += v; sq += v * v; n += 1
			grad += absf(img.get_pixel((x + 1) % img.get_width(), y).r - c.r)
	mean /= n
	var sd := (sq / n - mean * mean)
	return "media (%.3f %.3f %.3f) desvío (%.3f %.3f %.3f) detalle %.4f max %.2f" % [mean.x, mean.y, mean.z, sqrt(maxf(sd.x, 0)), sqrt(maxf(sd.y, 0)), sqrt(maxf(sd.z, 0)), grad / n, _max(img)]


func _max(img: Image) -> float:
	var m := 0.0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			m = maxf(m, img.get_pixel(x, y).r)
	return m
