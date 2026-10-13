@tool
class_name BigPot
extends PushBlock
## Vasija grande: se empuja como un bloque y se levanta (su Liftable la apoya con las manos quietas, en la celda de
## adelante). Tirada, soltada por un golpe o pegada con la espada, se rompe; rota, al salir el player de su sala
## vuelve entera a su lugar como un bloque.

@export var drops: DropTable
@export var burst: StringName = &"shards"
@export var sound: StringName = &"break"

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var liftable: Liftable = $Liftable

var broken := false


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	hurtbox.hit.connect(func(_info: DamageInfo) -> void: smash())


## La celda de adelante del player sobre la grilla en la que la pusieron; INF si no entra.
func drop_spot(from: Vector3, facing: Vector3, exclude: Array = []) -> Vector3:
	var ahead := from + PushBlock.axis(facing) * CELL
	var spot := _start + ((ahead - _start) / CELL).round() * CELL
	spot.y = from.y
	if not fits(spot, exclude) or not has_floor(spot):
		return Vector3.INF
	var space := get_world_3d().direct_space_state
	for height: float in [0.4, 1.0]:
		var ray := PhysicsRayQueryParameters3D.create(from + Vector3.UP * height, spot + Vector3.UP * height, MASK, [get_rid()] + exclude)
		if not space.intersect_ray(ray).is_empty():
			return Vector3.INF
	return spot


func lift_off() -> void:
	sync_to_physics = false
	_set_solid(false)


func set_down() -> void:
	moving = false
	sync_to_physics = true
	_set_solid(true)


func smash() -> void:
	if broken:
		return
	broken = true
	Feel.burst(burst, global_position + Vector3.UP * 0.5, Vector3.UP)
	Feel.sfx(sound, global_position)
	if drops:
		drops.drop_at.call_deferred(global_position, get_parent())
	visible = false
	_set_solid(false)


func reset_position() -> void:
	if get_parent() is ThrownObject or moving:
		return
	if broken:
		_restore()
		return
	super()


func _on_loaded() -> void:
	if get_parent() is ThrownObject:
		return
	if broken:
		_restore()
		return
	super()


func _restore() -> void:
	broken = false
	visible = true
	_set_solid(true)
	global_transform = Transform3D(Basis.IDENTITY, solved_position if is_solved() else _start)


func _set_solid(on: bool) -> void:
	shape.set_deferred(&"disabled", not on)
	hurtbox.set_deferred(&"monitorable", on)
	liftable.enabled = on
