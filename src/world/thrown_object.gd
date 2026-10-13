class_name ThrownObject
extends RigidBody3D
## El cuerpo físico de algo levantado (Liftable): lo sostiene el Carrier y, tirado, al chocar daña y se rompe.

const LAYER := 8

var liftable: Liftable
## Tirado o soltado: el próximo choque cuenta como impacto.
var flying := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not flying:
		return
	flying = false
	var hurtbox := body.get_node_or_null(^"Hurtbox") as Hurtbox
	if hurtbox and hurtbox.team != EntityConfig.Team.PLAYER:
		var info := DamageInfo.make(liftable.damage, 6.0, self)
		info.team = EntityConfig.Team.PLAYER
		hurtbox.receive(info)
	if liftable.breaks:
		_shatter.call_deferred()
	else:
		linear_velocity = Vector3(0.0, minf(linear_velocity.y, 0.0), 0.0)
		angular_velocity = Vector3.ZERO


## Fuera del callback de física: estallar reparenta el objeto.
func _shatter() -> void:
	liftable.shatter()
	queue_free()
