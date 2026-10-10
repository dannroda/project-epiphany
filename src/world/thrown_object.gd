class_name ThrownObject
extends RigidBody3D
## El cuerpo físico de algo levantado (Liftable): lo sostiene el Carrier y, tirado, al chocar daña y se rompe.

const LAYER := 8

var liftable: Liftable
## Tirado o soltado: el próximo choque cuenta como impacto.
var flying := false


func _init() -> void:
	collision_layer = LAYER
	collision_mask = 1 | LAYER
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	angular_damp = 4.0
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not flying:
		return
	flying = false
	var hurtbox := body.get_node_or_null(^"Hurtbox") as Hurtbox
	if hurtbox and hurtbox.team != EntityConfig.Team.PLAYER:
		var info := DamageInfo.new()
		info.amount = liftable.damage
		info.knockback = 6.0
		info.source = self
		info.team = EntityConfig.Team.PLAYER
		hurtbox.receive(info)
	if liftable.breaks:
		liftable.shatter()
		queue_free()
	else:
		linear_velocity = Vector3(0.0, minf(linear_velocity.y, 0.0), 0.0)
		angular_velocity = Vector3.ZERO
