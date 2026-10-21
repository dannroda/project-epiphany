extends RefCounted
## Tapas de las paredes LA (15.16): el mosaico plano de arriba de cada pieza (miles de triángulos de un color de la paleta
## sobre una grilla rectilínea) pasa a unos pocos quads que leen un atlas horneado sin filtrar. Se ve igual y el GPU del
## teléfono no pierde el tiempo en triángulos de menos de un pixel.

## Pixeles del atlas por metro.
const RES := 96.0
const PAD := 2
const ATLAS_WIDTH := 2048
## Grupos con menos triángulos quedan como están.
const MIN_TRIS := 16
const EPS := 0.0005


## Pasa a quads las tapas de los ítems `prefixes` del kit y guarda el atlas en `atlas_path`. Las piezas ya pasadas quedan igual.
static func apply(kit: MeshLibrary, prefixes: Array, atlas_path: String) -> void:
	var palettes := {}
	var jobs := []
	for item in kit.get_item_list():
		var mesh := kit.get_item_mesh(item) as ArrayMesh
		if mesh == null or not prefixes.any(func(prefix: String) -> bool: return kit.get_item_name(item).begins_with(prefix)):
			continue
		if range(mesh.get_surface_count()).any(func(s: int) -> bool: return _is_mosaic(mesh.surface_get_material(s))):
			continue
		for s in mesh.get_surface_count():
			var material := mesh.surface_get_material(s) as ShaderMaterial
			if material == null or material.get_shader_parameter("use_uv") != true:
				continue
			var palette := material.get_shader_parameter("albedo_texture") as Texture2D
			if not palettes.has(palette):
				var image := palette.get_image()
				image.decompress()
				palettes[palette] = image
			var groups := _caps(mesh.surface_get_arrays(s), palettes[palette])
			if not groups.is_empty():
				jobs.append({"item": item, "surface": s, "groups": groups, "material": material})
	if jobs.is_empty():
		return
	var shelf := Vector2i.ZERO
	var shelf_height := 0
	for job: Dictionary in jobs:
		for group: Dictionary in job.groups:
			var size := Vector2i(group.pixels) + Vector2i.ONE * PAD * 2
			if shelf.x + size.x > ATLAS_WIDTH:
				shelf = Vector2i(0, shelf.y + shelf_height)
				shelf_height = 0
			group.at = shelf + Vector2i.ONE * PAD
			shelf.x += size.x
			shelf_height = maxi(shelf_height, size.y)
	var atlas := Image.create_empty(ATLAS_WIDTH, shelf.y + shelf_height, false, Image.FORMAT_RGB8)
	for job: Dictionary in jobs:
		for group: Dictionary in job.groups:
			_paint(atlas, group)
	var texture := PortableCompressedTexture2D.new()
	texture.keep_compressed_buffer = true
	texture.create_from_image(atlas, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	ResourceSaver.save(texture, atlas_path)
	texture = ResourceLoader.load(atlas_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	var caps := {}
	for job: Dictionary in jobs:
		var material: ShaderMaterial = job.material
		if not caps.has(material):
			var cap := material.duplicate() as ShaderMaterial
			cap.set_shader_parameter("use_mosaic", true)
			cap.set_shader_parameter("mosaic_texture", texture)
			caps[material] = cap
		var mesh := kit.get_item_mesh(job.item) as ArrayMesh
		kit.set_item_mesh(job.item, _rebuilt(mesh, job.surface, job.groups, caps[material], Vector2(atlas.get_size())))


static func _is_mosaic(material: Material) -> bool:
	return material is ShaderMaterial and (material as ShaderMaterial).get_shader_parameter("use_mosaic") == true


## Las tapas de la superficie: por altura, los triángulos horizontales hacia arriba de un solo color con las esquinas en
## una grilla rectilínea. Las celdas que llenan pasan a quads; las que quedan a medias (un borde en diagonal), no.
static func _caps(arrays: Array, palette: Image) -> Array:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var by_height := {}
	for t in idx.size() / 3:
		var a := v[idx[t * 3]]
		var b := v[idx[t * 3 + 1]]
		var c := v[idx[t * 3 + 2]]
		if absf(a.y - b.y) > EPS or absf(a.y - c.y) > EPS or (b - a).cross(c - a).y > 0.0:
			continue
		var u := uv[idx[t * 3]]
		if not u.is_equal_approx(uv[idx[t * 3 + 1]]) or not u.is_equal_approx(uv[idx[t * 3 + 2]]):
			continue
		var key := snappedf(a.y, 0.0001)
		if not by_height.has(key):
			by_height[key] = []
		by_height[key].append(t)
	var groups := []
	for height: float in by_height:
		var tris: Array = by_height[height]
		if tris.size() < MIN_TRIS:
			continue
		var group := _grid(tris, v, uv, idx, palette)
		if not group.is_empty():
			group.height = v[idx[tris[0] * 3]].y
			groups.append(group)
	return groups


static func _grid(tris: Array, v: PackedVector3Array, uv: PackedVector2Array, idx: PackedInt32Array, palette: Image) -> Dictionary:
	var xs := {}
	var zs := {}
	for t: int in tris:
		for k in 3:
			xs[snappedf(v[idx[t * 3 + k]].x, 0.00001)] = true
			zs[snappedf(v[idx[t * 3 + k]].z, 0.00001)] = true
	var xl: Array = xs.keys()
	xl.sort()
	var zl: Array = zs.keys()
	zl.sort()
	var colors := {}
	var area := {}
	var of_cell := {}
	for t: int in tris:
		var a := v[idx[t * 3]]
		var b := v[idx[t * 3 + 1]]
		var c := v[idx[t * 3 + 2]]
		var center := (a + b + c) / 3.0
		var cell := Vector2i(xl.bsearch(center.x) - 1, zl.bsearch(center.z) - 1)
		for p in [a, b, c]:
			if not _on_corner(p, cell, xl, zl):
				return {}
		if not colors.has(cell):
			colors[cell] = []
		colors[cell].append([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z), _sample(palette, uv[idx[t * 3]])])
		area[cell] = area.get(cell, 0.0) + (b - a).cross(c - a).length() / 2.0
		if not of_cell.has(cell):
			of_cell[cell] = []
		of_cell[cell].append(t)
	var whole := []
	for cell: Vector2i in area:
		var full: float = (xl[cell.x + 1] - xl[cell.x]) * (zl[cell.y + 1] - zl[cell.y])
		if absf(area[cell] - full) > full * 0.02 + 0.000001:
			colors.erase(cell)
		else:
			whole.append_array(of_cell[cell])
	if whole.size() < MIN_TRIS:
		return {}
	var origin := Vector2(xl[0], zl[0])
	var pixels := Vector2i(ceili((xl.back() - xl[0]) * RES - 0.001), ceili((zl.back() - zl[0]) * RES - 0.001))
	return {"xl": xl, "zl": zl, "colors": colors, "origin": origin, "pixels": pixels, "tris": whole}


static func _on_corner(p: Vector3, cell: Vector2i, xl: Array, zl: Array) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x + 1 >= xl.size() or cell.y + 1 >= zl.size():
		return false
	var on_x := absf(p.x - xl[cell.x]) < EPS or absf(p.x - xl[cell.x + 1]) < EPS
	var on_z := absf(p.z - zl[cell.y]) < EPS or absf(p.z - zl[cell.y + 1]) < EPS
	return on_x and on_z


## El color con que el shader lee la paleta en esa UV (lineal, sin mipmaps: la UV no varía en el triángulo).
static func _sample(palette: Image, uv: Vector2) -> Color:
	var s := uv * Vector2(palette.get_size()) - Vector2(0.5, 0.5)
	var i := Vector2i(s.floor())
	var f := s - Vector2(i)
	var at := func(x: int, y: int) -> Color: return palette.get_pixel(posmod(x, palette.get_width()), posmod(y, palette.get_height()))
	var top: Color = at.call(i.x, i.y).lerp(at.call(i.x + 1, i.y), f.x)
	var bottom: Color = at.call(i.x, i.y + 1).lerp(at.call(i.x + 1, i.y + 1), f.x)
	return top.lerp(bottom, f.y)


## Cada texel con el color del triángulo donde cae su centro; fuera de la tapa (y en el borde), la celda ocupada más cercana.
static func _paint(atlas: Image, group: Dictionary) -> void:
	var xl: Array = group.xl
	var zl: Array = group.zl
	var colors: Dictionary = group.colors
	var nearest := {}
	for j in zl.size() - 1:
		for i in xl.size() - 1:
			var cell := Vector2i(i, j)
			if colors.has(cell):
				nearest[cell] = colors[cell]
				continue
			var best := INF
			for other: Vector2i in colors:
				var gap := (other - cell).length_squared()
				if gap < best:
					best = gap
					nearest[cell] = colors[other]
	var pixels: Vector2i = group.pixels
	for py in range(-PAD, pixels.y + PAD):
		var z: float = group.origin.y + (clampi(py, 0, pixels.y - 1) + 0.5) / RES
		var j := clampi(zl.bsearch(z) - 1, 0, zl.size() - 2)
		for px in range(-PAD, pixels.x + PAD):
			var x: float = group.origin.x + (clampi(px, 0, pixels.x - 1) + 0.5) / RES
			var i := clampi(xl.bsearch(x) - 1, 0, xl.size() - 2)
			atlas.set_pixel(group.at.x + px, group.at.y + py, _color_at(nearest[Vector2i(i, j)], Vector2(x, z)))


static func _color_at(tris: Array, point: Vector2) -> Color:
	for tri: Array in tris:
		if Geometry2D.point_is_inside_triangle(point, tri[0], tri[1], tri[2]):
			return tri[3]
	var best: Array = tris[0]
	var best_gap := INF
	for tri: Array in tris:
		var gap := point.distance_squared_to((tri[0] + tri[1] + tri[2]) / 3.0)
		if gap < best_gap:
			best = tri
			best_gap = gap
	return best[3]


## La superficie sin las tapas, y otra con sus quads: una grilla gruesa con las líneas donde cambia la ocupación, así los
## quads comparten lados enteros (sin uniones en T) y cubren justo las celdas de antes.
static func _rebuilt(mesh: ArrayMesh, surface: int, groups: Array, cap: ShaderMaterial, atlas_size: Vector2) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		if s != surface:
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(s))
			continue
		var removed := {}
		for group: Dictionary in groups:
			for t: int in group.tris:
				removed[t] = true
		var body := _without(arrays, removed)
		if not (body[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body)
			out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(s))
		var normal: Vector3 = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)[(arrays[Mesh.ARRAY_INDEX] as PackedInt32Array)[groups[0].tris[0] * 3]]
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for group: Dictionary in groups:
			_quads(tool, group, normal, atlas_size)
		tool.index()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tool.commit_to_arrays())
		out.surface_set_material(out.get_surface_count() - 1, cap)
	out.resource_name = mesh.resource_name
	return out


static func _without(arrays: Array, removed: Dictionary) -> Array:
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var remap := {}
	var kept := PackedInt32Array()
	for t in idx.size() / 3:
		if removed.has(t):
			continue
		for k in 3:
			var old := idx[t * 3 + k]
			if not remap.has(old):
				remap[old] = remap.size()
			kept.append(remap[old])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var order := remap.keys()
	for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]:
		if arrays[slot] == null:
			continue
		var source = arrays[slot]
		var copy = source.duplicate()
		copy.resize(order.size())
		for n in order.size():
			copy[n] = source[order[n]]
		out[slot] = copy
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var source: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var copy := PackedFloat32Array()
		copy.resize(order.size() * 4)
		for n in order.size():
			for k in 4:
				copy[n * 4 + k] = source[order[n] * 4 + k]
		out[Mesh.ARRAY_TANGENT] = copy
	out[Mesh.ARRAY_INDEX] = kept
	return out


static func _quads(tool: SurfaceTool, group: Dictionary, normal: Vector3, atlas_size: Vector2) -> void:
	var xl: Array = group.xl
	var zl: Array = group.zl
	var colors: Dictionary = group.colors
	var cols := [0, xl.size() - 1]
	var rows := [0, zl.size() - 1]
	for j in zl.size() - 1:
		for i in range(1, xl.size() - 1):
			if colors.has(Vector2i(i - 1, j)) != colors.has(Vector2i(i, j)) and i not in cols:
				cols.append(i)
	for i in xl.size() - 1:
		for j in range(1, zl.size() - 1):
			if colors.has(Vector2i(i, j - 1)) != colors.has(Vector2i(i, j)) and j not in rows:
				rows.append(j)
	cols.sort()
	rows.sort()
	var y: float = group.height
	for r in rows.size() - 1:
		for c in cols.size() - 1:
			if not colors.has(Vector2i(cols[c], rows[r])):
				continue
			var x0: float = xl[cols[c]]
			var x1: float = xl[cols[c + 1]]
			var z0: float = zl[rows[r]]
			var z1: float = zl[rows[r + 1]]
			var corners := [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]
			for k in [0, 1, 2, 0, 2, 3]:
				var p: Vector3 = corners[k]
				var texel: Vector2 = Vector2(group.at) + (Vector2(p.x, p.z) - group.origin) * RES
				tool.set_normal(normal)
				tool.set_tangent(Plane(1.0, 0.0, 0.0, 1.0))
				tool.set_uv(texel / atlas_size)
				tool.add_vertex(p)
