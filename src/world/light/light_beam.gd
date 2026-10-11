class_name LightBeam
extends Node3D
## Haz de luz desde este nodo hacia su -Z. Rebota en espejos (grupo light_mirror) y en el escudo espejo del player;
## activa los LightReceiver que toca. Se recalcula cada cuadro de física.

const MIRROR_GROUP := &"light_mirror"
const GLOW := preload("res://data/kits/materials/light_glow.tres")

@export var max_length := 40.0
@export var max_bounces := 8
@export var radius := 0.07
@export var color := Color(1.0, 0.92, 0.6)

## Los tramos del último cálculo (pares desde, hasta), para tests y depuración.
var segments: Array[PackedVector3Array] = []

var _material := StandardMaterial3D.new()
var _glow := GLOW.duplicate() as ShaderMaterial
var _meshes: Array[MeshInstance3D] = []
var _tip: MeshInstance3D


func _ready() -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = color
	_material.emission_enabled = true
	_material.emission = color
	_glow.set_shader_parameter(&"color", color)
	_tip = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius * 2.5
	sphere.height = radius * 5.0
	sphere.material = _material
	_tip.mesh = sphere
	_tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tip.material_overlay = _glow
	_tip.top_level = true
	add_child(_tip)


func _physics_process(_delta: float) -> void:
	segments.clear()
	var from := global_position
	var direction := -global_basis.z
	var remaining := max_length
	var exclude: Array[RID] = []
	for bounce in max_bounces + 1:
		var query := PhysicsRayQueryParameters3D.create(from, from + direction * remaining, 1, exclude)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			segments.append(PackedVector3Array([from, from + direction * remaining]))
			break
		var point: Vector3 = hit.position
		segments.append(PackedVector3Array([from, point]))
		remaining -= from.distance_to(point)
		var next: Variant = _next_direction(hit.collider, direction, hit.normal, point)
		if next == null or remaining <= 0.0:
			break
		from = point
		if next is Dictionary:
			from = next.origin
			next = next.direction
		direction = next
		exclude = [hit.rid]
	_draw()


func _next_direction(collider: Object, direction: Vector3, normal: Vector3, point: Vector3) -> Variant:
	if collider is LightReceiver:
		collider.receive_light()
		return null
	if collider is Node and (collider as Node).is_in_group(MIRROR_GROUP):
		return direction.bounce(normal).normalized()
	if collider is PlayerCharacter:
		return collider.light_hit(direction, point)
	return null


func _draw() -> void:
	while _meshes.size() < segments.size():
		var mesh := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = radius
		cylinder.bottom_radius = radius
		cylinder.height = 1.0
		cylinder.radial_segments = 8
		cylinder.rings = 1
		cylinder.material = _material
		mesh.mesh = cylinder
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.material_overlay = _glow
		mesh.top_level = true
		add_child(mesh)
		_meshes.append(mesh)
	for i in _meshes.size():
		var mesh := _meshes[i]
		mesh.visible = i < segments.size()
		if not mesh.visible:
			continue
		var a := segments[i][0]
		var b := segments[i][1]
		var length := a.distance_to(b)
		if length < 0.001:
			mesh.visible = false
			continue
		var up := (b - a) / length
		var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT).normalized()
		var basis := Basis(side, up * length, side.cross(up))
		mesh.global_transform = Transform3D(basis, (a + b) * 0.5)
	_tip.visible = not segments.is_empty()
	if _tip.visible:
		_tip.global_position = segments.back()[1]
