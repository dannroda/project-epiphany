extends SceneTree
## Prueba 12.14: la variante 8 (marching cubes) hecha en Godot en vez de Blender, desde el mismo mapa
## (tools/prueba_terreno_mapa.txt) y el mismo volumen. Arma levels/test/prueba_mc_godot.tscn: la malla con el shader
## terreno_mc (color por altura y pendiente), su colisión, la baranda del pozo y las plantas.
## godot --headless --path . --script res://tools/build_prueba_mc.gd

const MAP := "res://tools/prueba_terreno_mapa.txt"
const OUTPUT := "res://levels/test/prueba_mc_godot.tscn"
const MESHES := "res://assets/epiphany/meshes/prueba_mc_godot/"
const SHADER := preload("res://data/kits/shaders/terreno_mc.gdshader")
const PALETTE := preload("res://assets/epiphany/palette.png")
const NATURE := "res://assets/epiphany/meshes/naturaleza/%s.res"

const CELL := 2.0
const PAD := 3
const PAD_SOUTH := 4
const TOP := 2.6
const CAP := 0.15
const DEPTH := -3.0
const VOXEL := 0.33
const STRATA: Array[float] = [0.0, 0.12, 0.03, 0.16, 0.06, 0.13, 0.02]
const PATH_PIXEL := 0.125
## Por tipo de celda: [pieza, probabilidad]; hasta dos cosas por celda (como build_prueba_terreno.py).
const SCATTER := {
	".": [["ichu_mata", 0.35], ["flores", 0.14], ["piedra_chica_a", 0.08], ["piedra_chica_b", 0.06], ["tola", 0.06]],
	":": [["piedra_chica_b", 0.15]],
	"#": [["quenoa_grande", 0.16], ["quenoa_chica", 0.12], ["ichu_mata", 0.3], ["cardon_a", 0.06]],
	"H": [["ichu_mata", 0.25], ["flores", 0.1]],
	"T": [["quenoa_grande", 1.0]],
}

## Esquinas del cubo: bit 0 en x, bit 1 en z, bit 2 en y.
const CUBE: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]
const CUBE_FACES := [[0, 2, 6, 4], [1, 3, 7, 5], [0, 1, 5, 4], [2, 3, 7, 6], [0, 1, 3, 2], [4, 5, 7, 6]]

var _grid: PackedStringArray
var _w: int
var _h: int
var _gw: int
var _gh: int
var _low := Vector2.ZERO
var _high := Vector2.ZERO
var _warp := FastNoiseLite.new()
var _noise := FastNoiseLite.new()
var _edges := {}
var _cube_edges: Array[Vector2i] = []
var _ramp_south := 0.0


func _initialize() -> void:
	_read_map()
	_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_warp.frequency = 0.3
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0
	_noise.seed = 7
	for r in _gh:
		for c in _gw:
			if _grid[r][c] == "^" and _char_at(c, r + 1) != "^":
				_ramp_south = _corner(c, r + 1).y
	for kind in ["high", "pit", "ramp"]:
		_edges[kind] = _boundary(kind)
	var err := _build()
	print("prueba_mc_godot: ", error_string(err))
	quit(0 if err == OK else 1)


func _read_map() -> void:
	var rows := PackedStringArray()
	for line in FileAccess.get_file_as_string(MAP).split("\n", false):
		if not line.begins_with("# "):
			rows.append(line)
	_w = rows[0].length()
	_h = rows.size()
	var wall := "#".repeat(PAD)
	for i in PAD:
		_grid.append("#".repeat(_w + 2 * PAD))
	for row in rows:
		_grid.append(wall + row + wall)
	for i in PAD_SOUTH:
		_grid.append(wall + ".".repeat(_w) + wall)
	_gw = _grid[0].length()
	_gh = _grid.size()
	_low = _corner(0, 0)
	_high = _corner(_gw, _gh)


func _corner(c: int, r: int) -> Vector2:
	return Vector2((c - PAD - _w / 2.0) * CELL, (r - PAD - _h / 2.0) * CELL)


func _cell(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CELL + PAD + _w / 2.0), floori(z / CELL + PAD + _h / 2.0))


func _char_at(c: int, r: int) -> String:
	if r >= _gh:
		return "."
	if c < 0 or c >= _gw or r < 0:
		return "#"
	return _grid[r][c]


func _is(kind: String, ch: String) -> bool:
	match kind:
		"high":
			return ch == "#" or ch == "H"
		"pit":
			return ch == "~"
		"ramp":
			return ch == "^"
		"path":
			return ch == ":"
	return false


## Lados de celda entre lo de un tipo y lo demás, guardados en las celdas de los dos lados: {Vector2i: [[a, b], …]}.
func _boundary(kind: String) -> Dictionary:
	var result := {}
	var sides := [[Vector2i(0, 1), Vector2i(0, 1), Vector2i(1, 1)], [Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 1)], [Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1)]]
	for r in range(-1, _gh + 1):
		for c in range(-1, _gw + 1):
			if not _is(kind, _char_at(c, r)):
				continue
			for side: Array in sides:
				var n: Vector2i = Vector2i(c, r) + side[0]
				if _is(kind, _char_at(n.x, n.y)):
					continue
				var edge := [_corner(c + side[1].x, r + side[1].y), _corner(c + side[2].x, r + side[2].y)]
				for key: Vector2i in [Vector2i(c, r), n]:
					if not result.has(key):
						result[key] = []
					result[key].append(edge)
	return result


## Distancia al borde del tipo (positiva adentro, hasta 2 celdas), medida en el punto corrido por el ruido para que
## el contorno no salga recto.
func _signed(kind: String, x: float, z: float, warp: float) -> float:
	var p := Vector2(x, z)
	if warp > 0.0:
		p += Vector2(_warp.get_noise_2d(x, z), _warp.get_noise_2d(x + 71.0, z - 33.0)) * warp
	var home := _cell(p.x, p.y)
	var best := 2.0 * CELL
	var edges: Dictionary = _edges[kind]
	for dr in range(-2, 3):
		for dc in range(-2, 3):
			for edge: Array in edges.get(home + Vector2i(dc, dr), []):
				best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, edge[0], edge[1])))
	return best if _is(kind, _char_at(home.x, home.y)) else -best


func _build() -> Error:
	var nx := int((_high.x - _low.x) / VOXEL) + 1
	var nz := int((_high.y - _low.y) / VOXEL) + 1
	var y0 := DEPTH - 0.5
	var ny := int((TOP + 0.8 - y0) / VOXEL) + 1
	var columns := []
	for j in nz:
		for i in nx:
			var x := _low.x + i * VOXEL
			var z := _low.y + j * VOXEL
			columns.append(_column(x, z))
	var density := PackedFloat32Array()
	density.resize(nx * nz * ny)
	for k in ny:
		var y := y0 + k * VOXEL
		for j in nz:
			for i in nx:
				density[i + nx * (j + nz * k)] = _density(columns[i + nx * j], _low.x + i * VOXEL, y, _low.y + j * VOXEL)
	var surfaces := _march(density, nx, ny, nz, y0)
	DirAccess.make_dir_recursive_absolute(MESHES)
	var mesh := ArrayMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for part in ["suelo", "riscos"]:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var tris: PackedVector3Array = surfaces[part]
		for t in tris.size() / 3:
			var normal := (tris[t * 3 + 2] - tris[t * 3]).cross(tris[t * 3 + 1] - tris[t * 3]).normalized()
			tool.set_normal(normal)
			tool.set_color(Color(rng.randf(), 0, 0))
			for v in 3:
				tool.add_vertex(tris[t * 3 + v])
		tool.set_material(_material(part == "riscos"))
		tool.commit(mesh)
		print(part, ": ", tris.size() / 3, " triángulos")
	ResourceSaver.save(mesh, MESHES + "terreno.res")
	mesh = load(MESHES + "terreno.res")
	var shape := mesh.create_trimesh_shape()
	ResourceSaver.save(shape, MESHES + "terreno_col.res")
	shape = load(MESHES + "terreno_col.res")
	return _save_scene(mesh, shape, func(x: float, z: float) -> float: return _surface(x, z))


func _column(x: float, z: float) -> Array:
	return [
		_signed("high", x, z, 0.6),
		_signed("pit", x, z, 0.4),
		_signed("ramp", x, z, 0.0),
		0.3 * _warp.get_noise_3d(x, z, 37.0),
		clampf((_ramp_south - z) / (2.0 * CELL), 0.0, 1.0) * TOP,
	]


## Sólido donde es positiva: el suelo con lomas, los altos como columnas con estratos que salen y entran, la rampa y
## el pozo excavado (como volume_terrain de build_prueba_terreno.py).
func _density(column: Array, x: float, y: float, z: float) -> float:
	var row_height := (TOP - CAP + 0.5) / 6.0
	var row := clampi(roundi((y + 0.5) / row_height), 0, 6)
	var strata := STRATA[row] + 0.03 if y < TOP - CAP else 0.0
	var rough := _noise.get_noise_3d(x * 0.9, y * 0.9, z * 0.9)
	var high_column := minf(TOP + 0.04 * rough - y, column[0] + strata + 0.12 * rough)
	var solid := maxf(maxf(column[3] - y, high_column), minf(column[4] - y, column[2]))
	var carve := minf(column[1] + 0.25 * rough + 0.06 * minf(0.0, y), y - DEPTH)
	return minf(solid, -carve)


func _march(density: PackedFloat32Array, nx: int, ny: int, nz: int, y0: float) -> Dictionary:
	var table := _table()
	var ground := PackedVector3Array()
	var rocks := PackedVector3Array()
	var values: Array[float] = []
	values.resize(8)
	var where: Array[Vector3] = []
	where.resize(8)
	for k in ny - 1:
		for j in nz - 1:
			for i in nx - 1:
				var case_index := 0
				for c in 8:
					var o := CUBE[c]
					values[c] = density[(i + o.x) + nx * ((j + o.z) + nz * (k + o.y))]
					if values[c] > 0.0:
						case_index |= 1 << c
				if case_index == 0 or case_index == 255:
					continue
				var grad := Vector3.ZERO
				for c in 8:
					var o := CUBE[c]
					where[c] = Vector3(_low.x + (i + o.x) * VOXEL, y0 + (k + o.y) * VOXEL, _low.y + (j + o.z) * VOXEL)
					grad += Vector3(o.x * 2 - 1, o.y * 2 - 1, o.z * 2 - 1) * values[c]
				for tri: Array in table[case_index]:
					var v: Array[Vector3] = []
					for e: int in tri:
						var ab := _cube_edges[e]
						v.append(where[ab.x].lerp(where[ab.y], values[ab.x] / (values[ab.x] - values[ab.y])))
					var normal := (v[1] - v[0]).cross(v[2] - v[0])
					if normal.length_squared() < 1e-12:
						continue
					if normal.dot(grad) < 0.0:
						v = [v[0], v[2], v[1]]
						normal = -normal
					normal = -normal.normalized()
					var center := (v[0] + v[1] + v[2]) / 3.0
					if center.y > 0.5 or (normal.y < 0.8 and center.y > 0.1):
						rocks.append_array(PackedVector3Array(v))
					else:
						ground.append_array(PackedVector3Array(v))
	return {"suelo": ground, "riscos": rocks}


## Triángulos (en aristas del cubo) de los 256 casos, como _mc_table de build_prueba_terreno.py.
func _table() -> Array:
	var edge_id := {}
	for a in 8:
		for b in range(a + 1, 8):
			if (a ^ b) in [1, 2, 4]:
				edge_id[Vector2i(a, b)] = _cube_edges.size()
				_cube_edges.append(Vector2i(a, b))
	var table := []
	for case_index in 256:
		var segments := []
		for face: Array in CUBE_FACES:
			var sides := []
			for k in 4:
				var a: int = face[k]
				var b: int = face[(k + 1) % 4]
				sides.append(edge_id[Vector2i(mini(a, b), maxi(a, b))])
			var cut := []
			for k in 4:
				if ((case_index >> face[k]) & 1) != ((case_index >> face[(k + 1) % 4]) & 1):
					cut.append(k)
			if cut.size() == 2:
				segments.append([sides[cut[0]], sides[cut[1]]])
			elif cut.size() == 4:
				for k in 4:
					if (case_index >> face[k]) & 1:
						segments.append([sides[(k + 3) % 4], sides[k]])
		var tris := []
		while not segments.is_empty():
			var first: Array = segments.pop_back()
			var poly := [first[0], first[1]]
			while true:
				var next := -1
				for s in segments.size():
					if poly[-1] in segments[s]:
						next = s
						break
				if next < 0:
					break
				var seg: Array = segments.pop_at(next)
				var other: int = seg[1] if seg[0] == poly[-1] else seg[0]
				if other == poly[0]:
					break
				poly.append(other)
			for t in range(1, poly.size() - 1):
				tris.append([poly[0], poly[t], poly[t + 1]])
		table.append(tris)
	return table


func _material(wall: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("palette", PALETTE)
	material.set_shader_parameter("path_mask", load(MESHES + "camino.res") if ResourceLoader.exists(MESHES + "camino.res") else _path_mask())
	material.set_shader_parameter("path_rect", Vector4(_low.x, _low.y, _high.x - _low.x, _high.y - _low.y))
	material.set_shader_parameter("cut_hole", wall)
	return material


## El camino como imagen vista desde arriba (1 = tierra), con el mismo ruido que los bordes y unos dientes chicos.
func _path_mask() -> ImageTexture:
	var size := Vector2i(int((_high.x - _low.x) / PATH_PIXEL), int((_high.y - _low.y) / PATH_PIXEL))
	var image := Image.create(size.x, size.y, false, Image.FORMAT_L8)
	for py in size.y:
		for px in size.x:
			var x := _low.x + (px + 0.5) * PATH_PIXEL
			var z := _low.y + (py + 0.5) * PATH_PIXEL
			var jag := _noise.get_noise_2d(x * 3.0, z * 3.0) * 0.08
			var p := Vector2(x, z) + Vector2(_warp.get_noise_2d(x * 1.3, z * 1.3), _warp.get_noise_2d(z * 1.3 + 9.0, x * 1.3)) * 0.5 + Vector2(jag, jag)
			var cell := _cell(p.x, p.y)
			image.set_pixel(px, py, Color.WHITE if _char_at(cell.x, cell.y) == ":" else Color.BLACK)
	var texture := ImageTexture.create_from_image(image)
	ResourceSaver.save(texture, MESHES + "camino.res")
	return load(MESHES + "camino.res")


## Altura del suelo arriba de todo en (x, z), bajando por la densidad; NAN si ahí no se puede poner nada.
func _surface(x: float, z: float) -> float:
	var column := _column(x, z)
	var y := TOP + 0.8
	var previous := _density(column, x, y, z)
	while y > DEPTH - 0.4:
		var next_y := y - 0.05
		var value := _density(column, x, next_y, z)
		if value > 0.0 and previous <= 0.0:
			var hit := lerpf(y, next_y, previous / (previous - value))
			var slope := Vector2(_density(_column(x + 0.1, z), x + 0.1, hit, z) - _density(_column(x - 0.1, z), x - 0.1, hit, z), _density(_column(x, z + 0.1), x, hit, z + 0.1) - _density(_column(x, z - 0.1), x, hit, z - 0.1)).length() / 0.2
			return hit if slope < 0.6 and hit > -0.5 else NAN
		previous = value
		y = next_y
	return NAN


func _save_scene(mesh: ArrayMesh, shape: Shape3D, surface: Callable) -> Error:
	var root := Node3D.new()
	root.name = "PruebaMcGodot"
	var terrain := MeshInstance3D.new()
	terrain.name = "Terreno"
	terrain.mesh = mesh
	root.add_child(terrain)
	var body := StaticBody3D.new()
	body.name = "Colision"
	root.add_child(body)
	var collider := CollisionShape3D.new()
	collider.name = "Forma"
	collider.shape = shape
	body.add_child(collider)
	root.add_child(_rail())
	var plants := Node3D.new()
	plants.name = "Plantas"
	root.add_child(plants)
	var rng := RandomNumberGenerator.new()
	for r in _gh:
		for c in _gw:
			var ch := _grid[r][c]
			rng.seed = r * 131 + c + 17
			var placed := 0
			for entry: Array in SCATTER.get(ch, []):
				if placed >= 2 or rng.randf() >= entry[1]:
					continue
				var center := (_corner(c, r) + _corner(c + 1, r + 1)) / 2.0
				var jitter := 0.0 if ch == "T" else 0.6
				var x := center.x + rng.randf_range(-jitter, jitter)
				var z := center.y + rng.randf_range(-jitter, jitter)
				var y: float = surface.call(x, z)
				if is_nan(y):
					continue
				var plant := MeshInstance3D.new()
				plant.name = "%s_%d" % [entry[0], plants.get_child_count()]
				plant.mesh = load(NATURE % entry[0])
				plant.position = Vector3(x, y, z)
				plant.rotation.y = rng.randf() * TAU
				plants.add_child(plant)
				placed += 1
	for node in root.find_children("*", "", true, false):
		node.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return ResourceSaver.save(packed, OUTPUT)


## Baranda invisible al borde del pozo: una caja fina por cada lado de celda, un poco hacia afuera.
func _rail() -> StaticBody3D:
	var rail := StaticBody3D.new()
	rail.name = "Baranda"
	var seen := {}
	for edges: Array in _edges["pit"].values():
		for edge: Array in edges:
			var key := str(edge)
			if seen.has(key):
				continue
			seen[key] = true
			var a: Vector2 = edge[0]
			var b: Vector2 = edge[1]
			var mid := (a + b) / 2.0
			var cell := _cell(mid.x + (b - a).orthogonal().normalized().x * 0.1, mid.y + (b - a).orthogonal().normalized().y * 0.1)
			var out := (b - a).orthogonal().normalized() * (-1.0 if _is("pit", _char_at(cell.x, cell.y)) else 1.0)
			var box := BoxShape3D.new()
			box.size = Vector3(a.distance_to(b) + 0.9, 1.6, 0.1)
			var collider := CollisionShape3D.new()
			collider.name = "Lado%d" % rail.get_child_count()
			collider.shape = box
			var spot := mid + out * 0.6
			collider.position = Vector3(spot.x, 0.6, spot.y)
			collider.rotation.y = -atan2(b.y - a.y, b.x - a.x)
			rail.add_child(collider)
	return rail
