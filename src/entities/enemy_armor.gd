class_name EnemyArmor
extends Node
## Coraza: rebota todo salvo explosiones, martillazos y `torn_by`; esos la vuelan, y `torn_by` además sin dañar.

signal broken

const PIECE := preload("res://src/entities/armor_piece.tscn")

@export var body: Node3D
## La malla que sale volando.
@export var mesh: Node3D
## El elemento que la arranca sin dañar (el gancho).
@export var torn_by: StringName


func is_on() -> bool:
	return mesh != null


func stops(info: DamageInfo) -> bool:
	if not is_on():
		return false
	if info.element == DamageInfo.EXPLOSIVE or info.element == torn_by or info.strong:
		_break()
		return info.element == torn_by
	Feel.sfx(&"block", body.global_position)
	var forward := body.global_basis.z * Vector3(1, 0, 1)
	var from := info.source.global_position if info.source else body.global_position + forward
	var toward := ((from - body.global_position) * Vector3(1, 0, 1)).normalized()
	Feel.burst(&"sparks", body.global_position + Vector3.UP * 1.3 + toward * 0.4, toward + Vector3.UP * 0.3)
	return true


func _break() -> void:
	var at := mesh.global_transform
	mesh.get_parent().remove_child(mesh)
	_fling.call_deferred(mesh, at)
	mesh = null
	Feel.burst(&"shards", body.global_position + Vector3.UP * 1.3, Vector3.UP)
	Feel.sfx(&"boom", body.global_position)
	Log.debug(&"combat", body.name, "perdió la coraza")
	broken.emit()


## Diferido: el golpe llega en un callback de física y acá se agrega un cuerpo nuevo.
func _fling(armor: Node3D, at: Transform3D) -> void:
	var piece := PIECE.instantiate() as RigidBody3D
	body.get_parent().add_child(piece)
	piece.global_transform = at
	piece.add_child(armor)
	armor.transform = Transform3D.IDENTITY
	piece.linear_velocity = Vector3.UP * 5.0 - (body.global_basis.z * Vector3(1, 0, 1)).normalized() * 2.0
	piece.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	var fade := piece.create_tween()
	fade.tween_interval(2.5)
	fade.tween_callback(piece.queue_free)
