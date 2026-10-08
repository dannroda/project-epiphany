class_name Breakable
extends Node3D
## Vasijas y pasto: se rompen con cualquier golpe (espada, bomba), sueltan según su DropTable y reaparecen al recargar.

@export var drops: DropTable
@export var burst: StringName = &"shards"
@export var sound: StringName = &"break"
@export var drop_height := 0.0

@onready var hurtbox: Hurtbox = $Hurtbox

var broken := false


func _ready() -> void:
	hurtbox.hit.connect(func(_info: DamageInfo) -> void: smash())


func smash() -> void:
	if broken:
		return
	broken = true
	Feel.burst(burst, global_position + Vector3.UP * 0.3, Vector3.UP)
	Feel.sfx(sound, global_position)
	if drops:
		drops.drop_at.call_deferred(global_position + Vector3.UP * drop_height, get_parent())
	queue_free()
